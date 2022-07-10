// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.6;

interface IParetoVault {
    /************************************************
     * Vault Operations
     ***********************************************/

    /**
     * @notice Deposits risky asset from `msg.sender` to the vault address.
     *         Updates the deposit receipt associated with `msg.sender` in rollover
     * @dev Emits `DepositEvent`
     * @param riskyAmount Amount of risky asset to deposit
     */
    function deposit(uint256 riskyAmount) external;

    /**
     * @notice User requests a withdrawal that can be completed after the current round.
     *         Cannot request more shares than than the user obtained through deposits.
     *         Multiple requests can be made for the same round
     * @dev Emits `WithdrawRequestEvent`
     * @param shares Number of shares to withdraw
     */
    function requestWithdraw(uint256 shares) external;

    /**
     * @notice Users call this function to complete a requested withdraw from a past round.
     *         A withdrawal request must have been made via requestWithdraw.
     *         This function must be called after the round
     * @dev Emits `WithdrawCompleteEvent`.
     *      Burns receipts, and transfers tokens to `msg.sender`
     */
    function completeWithdraw() external;

    /**
     * @notice Returns the balance held in the vault for one account in risky and stable tokens
     * @param account Address to lookup balance for
     * @return riskyAmount Risky asset owned by the vault for the user
     * @return stableAmount Stable asset owned by the vault for the user
     */
    function getAccountBalance(address account)
        external
        view
        returns (uint256 riskyAmount, uint256 stableAmount);

    /************************************************
     * View Functions
     ***********************************************/

    /**
     * @notice Address of the `ParetoManager` contract to choose the next vault
     * @return Address of the ParetoManager contract
     */
    function vaultManager() external view returns (address);

    /**
     * @notice Keeper who manually managers contract via deployment and rollover
     * @dev No access to critical vault changes
     * @return Address of the keeper
     */
    function keeper() external view returns (address);

    /**
     * @notice Recipient of the fees charged each rollover
     * @return Address of the fee recipient
     */
    function feeRecipient() external view returns (address);

    /**
     * @notice Risky token of the risky / stable pair
     * @return Address of the risky token contract
     */
    function risky() external view returns (address);

    /**
     * @notice Stable token of the risky / stable pair
     * @return Address of the stable token contract
     */
    function stable() external view returns (address);
}
