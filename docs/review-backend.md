# Meeto 后端 Review 指南

NestJS + Prisma（SQLite）单体（`server/`，:3000，无全局路由前缀）。业务：用户（USER）按平台模板发起活动并付费，搭子（HOST）报名陪伴赚钱；资金平台托管，活动完成后结算，平台抽佣（默认 10%，运行时可调）。

## 跑起来

```bash
cd server && npm install
npx prisma db push && node prisma/seed.mjs && node prisma/fixtures.e2e.mjs   # 开发库 + 种子 + 大厅演示数据
npm run start                                 # :3000
npm run test:e2e                              # 81 条端到端测试（vitest + supertest，独立 test.db 每次重建）
```

## 核心业务逻辑

### 两条成单路径

1. **帖子路径**：USER 按模板发帖（`Post`，模板定场景/地点/封面，发布者定时间和价格档）→ HOST 报名（`Application`）→ 发帖人选人 → 生成订单。
2. **提案路径**：HOST 发提案（`Proposal`，只选时段不定价）→ USER 邀请（`Invitation`，邀请时定具体时间和价格档）→ HOST 选邀请人 → 生成订单。

两条路径殊途同归到同一个 `Order`，`syncProposal` 保持提案状态与订单联动。

### 订单状态机（`orders/orders.service.ts`）

```
AWAITING_PAYMENT --pay--> ACTIVE --meet code start--> (服务计时) --时长到--> COMPLETED
       |                    |                                   
       |超时30min未付        |--双方任一方取消(成单30min内)--> CANCELLED（全额退款）
       v                    |--24h 无人 start--> FORFEITED（托管归平台，双方都不拿）
   CANCELLED                |--admin 强退--> CANCELLED
```

- **懒结算**：没有定时任务。`maybeSettle` 在每次读单时核对时钟并推进状态（过期取消/结算/作废）。时间窗可用 env 覆盖：`PAY_WINDOW_MS`（默认 30min）、`CANCEL_WINDOW_MS`（30min）、`FORFEIT_AFTER_MS`（24h）。
- **见面密码**：4 位码只向付款方披露；HOST 当面问到后提交 `POST /orders/:id/start` 启动服务计时，这是"真的见面了"的凭证。
- **举报冻结**：任一参与方 `POST /orders/:id/report` 后，OPEN 状态的举报会让 `maybeSettle` 既不结算也不作废，直到 admin resolve（兑现社区公约"审核期间结算冻结"）。

### 资金与账本（`ledger/`）

复式记账，`LedgerEntry` 不可变追加。支付时 `ESCROW_IN`；结算时四分录（托管转出、HOST 收入、平台佣金、按 `platformFeeRateBp` 计算）；退款 `ESCROW_REFUND` 负额对冲。钱包余额、可提现额全部由账本聚合推导，没有冗余余额字段。提现（`Withdrawal`）目前只记流水，实际打款人工处理。

### 并发控制（review 重点）

所有状态翻转用**条件更新原子认领**，不用 check-then-act：

```ts
const claimed = await tx.order.updateMany({
  where: { id, status: OrderStatus.active },   // 状态即锁
  data: { status: OrderStatus.cancelled },
});
if (claimed.count === 0) throw new ConflictException(...);
```

应用于：双付、双选人、双 start、双取消、admin 强退。e2e 里有 `Promise.all` 双发的竞态测试覆盖。

### 安全

- `AuthGuard`：JWT（access 7d / refresh 30d）；每请求查库并拦截 `BANNED` 账号（封号即时生效，不等 token 过期）。**`X-User-Id` 演示后门仅 `NODE_ENV !== 'production'` 时开放**，e2e 和本地调试用。
- `AdminGuard`：`role === 'ADMIN'` 才能进 `/admin/*`。
- 上传：mime 白名单（jpeg/png/webp/heic），存储文件名服务端生成（UUID+由 mime 推导的扩展名，完全不信任客户端文件名，防存储型 XSS/路径穿越），8MB 上限。
- 敏感披露控制：电话仅托管后对双方互露；meet code 仅付款方可见（admin 视图也不露）。

## API 一览（按 controller）

| 前缀 | 端点 |
|---|---|
| `/auth` | POST `otp/request`、`otp/verify`、`register`、`refresh` |
| `/users` | GET/PATCH `me`，GET `:id` |
| `/templates` | GET（平台精选活动模板，发布唯一入口） |
| `/posts` | GET、POST、DELETE `:id`（作者或 ADMIN）、GET `:id`、GET/POST `:id/applications`、POST `:id/selection`、GET `signups/notice` |
| `/proposals` | GET、POST、GET `:id`、POST/GET `:id/invitations`、POST `:id/invitations/:invId/select` |
| `/orders` | GET（`?view=all`）、GET `conversations`、GET `:id`、POST `:id/payment`、`:id/start`、`:id/cancel`、`:id/report`、消息三件套（发送/邀约卡/响应）、GET `:id/messages` |
| `/wallet` | GET、GET/POST `withdrawals` |
| `/verification` | POST（mock 直接通过） |
| `/uploads` | POST（multipart） |
| `/places` | GET `search`（Amap 代理，需 `AMAP_KEY`） |
| `/config` | GET `pricing`（公开） |
| `/admin` | PUT `pricing`、GET `orders`、GET `users?q=`、POST `users/:id/ban|unban`、POST `orders/:id/refund`、GET `reports`、POST `reports/:id/resolve` |

错误口径：业务冲突 409（含 `PAYMENT_REQUIRED`、`CHAT_CLOSED`、`ALREADY_STARTED` 等语义码）、权限 403（`ACCOUNT_BANNED`、`VERIFICATION_REQUIRED`）、校验 400。

## 预留的外部接缝（现为 mock）

- `SMS_PROVIDER`（`auth/sms.provider.ts`）：OTP 固定 123456，非生产回显给客户端；
- `PAYMENT_PROVIDER`（`payments/payment.provider.ts`）：charge 即成功、refund 为 no-op，GCash/Maya 从这里替换；
- 真人认证（`verification/`）：有头像即通过，真实 KYC 厂商替换时走 PENDING 审核态；
- 地点搜索：Amap 仅覆盖中国大陆，东南亚需换 provider（端点不变）。

## 已知欠缺 / 风险（请重点评审）

1. **OTP 无防刷限流**——接真实短信前必须加（按手机号+IP 限频），否则短信费被刷爆；
2. **无通知系统**——成单/被选中/收到举报全靠客户端轮询；
3. **SQLite 单文件**——并发写入上量后需迁 Postgres（Prisma 层迁移成本低）；
4. **懒结算依赖读取**——无人读的订单状态停留在过期前的样子（账目最终一致，但统计类查询要先触发结算）；
5. **提现为人工流程**——只记申请流水，无打款对账；
6. 无评价体系、无风控（同人多账号、刷单）。
