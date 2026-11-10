# Meeto 前端 Review 指南

移动优先的 Vue 3 web 应用（`web/`），模板制活动搭子平台：用户发活动付费，搭子报名陪伴赚钱，平台托管资金抽佣。运营后台是独立项目 `web-admin`（同样的联调约定）。

## 跑起来

```bash
cd server && npm install && npx prisma db push && node prisma/seed.mjs && npm run start   # :3000
cd web && npm install && npm run dev                                                       # :5173
```

技术栈：Vue 3 `<script setup>` + TypeScript + Pinia + vue-router，无 UI 库，样式全手写（`src/styles/base.css` 设计 token + 各组件 scoped css）。桌面端渲染为居中 480px 手机框。

演示账号：任意手机号登录，验证码固定 `123456`（页面会回显）。管理员 `+639170000001`。

## 联调约定（review 重点）

- **代理**：dev 下所有请求走 `/api/*`，由 Vite 代理到 `:3000` 并去掉 `/api` 前缀（`vite.config.ts`）。后端本身没有全局前缀。生产用 `VITE_API_BASE_URL` 覆盖。
- **认证**：JWT 双 token。`accessToken` 放 `Authorization: Bearer`，7 天；`refreshToken` 30 天。封装在 `src/api/client.ts`：
  - 401 → 自动调 `/auth/refresh` 换新对，重试原请求一次；刷新也失败 → 清 session 硬跳 `/login`；
  - 403 且 body 含 `ACCOUNT_BANNED` → 被封号，清 session 跳登录；
  - 并发请求共享同一个刷新 Promise，不会重复刷新。
- **session**：localStorage key `meeto.session`（Pinia store `src/stores/session.ts`），含双 token 和用户摘要。角色 `USER`（发活动付钱）/ `HOST`（陪伴赚钱）注册时定死，大厅按角色隔离（互相只看对面侧的内容）。
- **金额**：API 一律分单位（centavos，`feeMinor`），`client.ts` 的 `minorToMajor/majorToMinor` 换算，UI 显示整比索 `₱1,500`。
- **时间**：API 为 ISO 字符串，mapper 层转 `Date`；订单结算是服务端"读时懒结算"，所以前端靠轮询（订单房间 5s 一拉）刷新状态，没有推送。
- **媒体**：上传 `POST /uploads`（multipart，仅 jpeg/png/webp/heic，≤8MB），返回根相对路径 `/uploads/xxx.png`，渲染时用 `resolveMediaUrl` 拼 API host。
- **mapper 层**：`src/api/mappers.ts` 是服务端 DTO → 前端模型（`src/types/models.ts`）的唯一翻译点，字段改动先看这里。

## 还没接的 SDK / 真实能力（现在全是演示桩）

| 能力 | 现状 | 要接什么 |
|---|---|---|
| 短信 OTP | 验证码固定 123456，非生产环境 API 直接回显 | 短信网关（菲律宾号码：Semaphore / Twilio），同时后端要加防刷限流 |
| 活体检测 | 前端有完整引导流程 UI（眨眼/转头步骤、闪光提示），实际只拍一张自拍上传，后端无条件通过 | 活体+人脸比对 SDK（商汤/旷视/AWS Rekognition 等），接入点在 `VerificationPage.vue` |
| 支付 | 演示支付：点击即成功，无真实扣款 | GCash / Maya 收银台或聚合支付，接入点在 `PayPage.vue`（后端已预留 provider 接口） |
| IM | 订单房间内轮询拉消息（5s），无长连接、无已读、无输入中状态 | 云信 / 环信 / 自建 WebSocket；当前消息模型在 `OrderRoomPage.vue` |
| 推送通知 | 无。成单/被选中/收到邀请全靠用户自己刷新 | 浏览器 Push / 接 App 后走厂商通道 |
| 地图选点 | 地点搜索走后端 Amap 代理（需配 `AMAP_KEY`，只覆盖中国大陆），无地图可视化 | 东南亚上线要换 Google Places，端点不变（`/places/search`） |
| 对象存储 | 上传的图片存后端本地磁盘 | OSS/S3 + CDN，前端无需改动（URL 结构不变） |

## 建议 review 的点

1. `src/api/client.ts` 的 token 刷新与错误分流是否有边界遗漏；
2. 轮询驱动的状态同步（`OrderRoomPage.vue`）在弱网/后台 tab 下的表现；
3. 发布器草稿暂存（`ComposerPage.vue` 的 sessionStorage 方案）；
4. 大厅/详情页的角色隔离逻辑是否有绕过路径；
5. 组件层较薄（8 个共享组件），页面文件偏大（`OrderRoomPage.vue` 千行级），是否需要拆分。
