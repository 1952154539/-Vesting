# Vesting 合约

一个基于 Solidity 的线性解锁（Vesting）合约，使用 Foundry 框架开发。该合约实现了 Cliff（悬崖期）+ 线性解锁的标准代币释放方案。

## 概念解释

### Vesting（解锁/归属）
Vesting 是指代币按照预定的时间表逐步解锁给受益人的过程。这是区块链行业中常见的机制，用于激励团队、顾问和投资者长期参与项目。

### Cliff（悬崖期）
Cliff 是指受益人必须等待的最短时间，在此之前不能获得任何代币。本项目设置 **12 个月** 的悬崖期。如果受益人在悬崖期内离开项目，将不会获得任何代币。

### 线性解锁（Linear Vesting）
悬崖期结束后，代币在一个固定周期内**线性释放**。本项目设置为悬崖期后的 **24 个月内，每月解锁总量的 1/24**。

## 参数说明

| 参数 | 值 | 说明 |
|------|-----|------|
| `beneficiary` | 指定地址 | 受益人地址 |
| `token` | ERC20 合约地址 | 锁定的代币合约 |
| `totalAmount` | 1,000,000 代币 | 锁定总量 |
| `CLIFF_DURATION` | 365 天（12个月） | 悬崖期长度 |
| `VESTING_DURATION` | 730 天（24个月） | 线性解锁周期 |

## 时间线

```
部署时刻                                完全解锁
   |---- 12个月 Cliff ----|---- 24个月 线性解锁 ----|
   |   0% 释放             |   每月 1/24 线性释放    |
```

- **月份 1-12（Cliff）**: 释放量为 0
- **月份 13-36（线性解锁）**: 每月解锁总量的 1/24
- **36个月后**: 100% 解锁

## 合约方法

### `release()`
释放当前已解锁的代币给受益人。任何人可以调用，代币只会转给受益人。

### `vestedAmount()`
查询目前已解锁的代币数量。返回 `uint256`。

### `releasable()`
查询当前可释放的代币数量（已解锁但尚未释放的部分）。返回 `uint256`。

## 快速开始

### 环境要求
- [Foundry](https://book.getfoundry.sh/getting-started/installation)

### 安装依赖

```bash
forge install
```

### 编译

```bash
forge build
```

### 运行测试

```bash
forge test -vvv
```

### 部署

```bash
# 设置环境变量
cp .env.example .env
# 编辑 .env 填入实际参数

# 部署
forge script script/Deploy.s.sol --broadcast --rpc-url <RPC_URL>
```

## 测试说明

测试使用 Foundry 的 `vm.warp()` 进行时间模拟，覆盖以下场景：

| 测试 | 说明 |
|------|------|
| `test_InitialState` | 验证合约初始状态 |
| `test_NoReleaseDuringCliff` | 悬崖期内无代币可释放 |
| `test_VestingStartsAfterCliff` | 悬崖期后开始解锁 |
| `test_OneMonthAfterCliff` | 悬崖期后1个月，约 1/24 解锁 |
| `test_HalfVested` | 12个月后约 50% 解锁 |
| `test_FullyVested` | 36个月后 100% 解锁 |
| `test_BeyondFullVesting` | 超期后仍为 100% |
| `test_Release` | 正常释放流程 |
| `test_ReleaseRevertsWhenNothingToRelease` | 无代币可释放时 revert |
| `test_MultipleReleases` | 多次释放累积验证 |
| `test_AnyoneCanRelease` | 任何人都可以调用 release |
| `test_ReleaseSendsToBeneficiary` | 代币只发给受益人 |

## 项目结构

```
├── src/
│   ├── Vesting.sol      # Vesting 合约
│   └── MockERC20.sol    # 测试用 ERC20
├── test/
│   └── Vesting.t.sol    # 测试文件（含时间模拟）
├── script/
│   └── Deploy.s.sol     # 部署脚本
├── lib/                 # 依赖（OpenZeppelin, forge-std）
└── foundry.toml         # Foundry 配置
```

## License

MIT
