## InheritanceVault

**What it is**: A simple ETH vault with a dead man's switch. The `owner` can withdraw funds or send a heartbeat by calling `withdraw(0)`. If the owner is inactive for 30 days, the `heir` can claim ownership and set a new heir.

### Contract functions (brief)
- **constructor(address _heir)**: Sets deployer as `owner` and `_heir` as `heir`. Reverts if `_heir` is zero or equals `msg.sender`.
- **withdraw(uint256 amount)**: Owner-only. Updates heartbeat. If `amount > 0`, sends ETH to `owner`; if `0`, just refreshes inactivity timer.
- **updateHeir(address _newHeir)**: Owner-only. Updates `heir`. Reverts on zero address or if set to `owner`.
- **claimOwnership(address _newHeir)**: Heir-only and only after 30 days of inactivity. Transfers `owner` to caller, sets `_newHeir`, and refreshes heartbeat.
- **receive() external payable**: Accepts ETH deposits and emits a `Deposited` event.
- **getBalance()**: Returns the vault's ETH balance.
- **getTimeUntilClaimable()**: Seconds remaining until the heir can claim; returns `0` if already claimable.
- **canHeirClaim()**: Returns `true` if the 30-day inactivity period has elapsed.
