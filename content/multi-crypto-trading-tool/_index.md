+++
title = "Multi Crypto Trading Tool"
type = "section"
weight = 1
+++

### Project Overview

This project is designed to aggregate real-time data from multiple cryptocurrency exchanges and execute automated trades using a variety of strategies. Performance and scalability are key priorities in its development.

---

### 📊 System Architecture

To better illustrate the architecture of this project, the diagram below shows how different components interact within a Docker Compose environment:

![System Architecture](/images/projects/mcttool/system-architecture.png)

- All services communicate over a shared Docker network.
- The **Core Layer** includes the frontend, backend, and worker services.
- The **Infra Layer** consists of Redis (for both queuing and caching).
- The **Monitoring Layer** captures metrics using Prometheus and displays dashboards via Grafana.

---

### 📁 Dev Logs

- [1. Project Initialization](/multi-crypto-trading-tool/dev-logs/initializeProject/)
- [2. Start Backend](/multi-crypto-trading-tool/dev-logs/startBackend/)
- [3. Logger Configuration](/multi-crypto-trading-tool/dev-logs/loggerConfig/)
- [4. Set Configuration](/multi-crypto-trading-tool/dev-logs/setConfig/)
- [5. Database Connection Manager](/multi-crypto-trading-tool/dev-logs/databaseConnMng/)
- [6. Login Page Setup](/multi-crypto-trading-tool/dev-logs/login/)
- [7. Topbar Menu](/multi-crypto-trading-tool/dev-logs/topBarMenu/)
- [8. Login Log](/multi-crypto-trading-tool/dev-logs/loginlog/)
- [9. Refactoring 1: Backend - Separate AuthService and Move Login API](/multi-crypto-trading-tool/dev-logs/refactor1/)
- [10. Managing API Keys - Backend Implementation](/multi-crypto-trading-tool/dev-logs/mngapikeys1/)
- [11. Managing API Keys - Frontend Implementation](/multi-crypto-trading-tool/dev-logs/mngapikeys2/)
- [12. Refactoring 2: Backend - Applying Async Database Management](/multi-crypto-trading-tool/dev-logs/refactor2/)
