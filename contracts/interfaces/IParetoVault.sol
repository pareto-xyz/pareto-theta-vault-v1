// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.6;

interface IParetoVault {
    /************************************************
     * Vault Operations
     ***********************************************/

    /**
     * @notice Deposits risky asset from msg.sender.
     * @param riskyAmount is the amount of risky asset to deposit
     */
    function deposit(uint256 riskyAmount) external;

    /**
     * @notice Requests a withdraw that is processed after the current round
     * @param shares is the number of shares to withdraw
     */
    function requestWithdraw(uint256 shares) external;

    /**
     * @notice Completes a requested withdraw from past round.
     */
    function completeWithdraw() external;

    /**
     * @notice Returns the asset balance held in the vault for one account
     * @param account is the address to lookup balance for
     * @return riskyAmount is the risky asset owned by the vault for the user
     * @return stableAmount is the stable asset owned by the vault for the user
     */
    function getAccountBalance(address account)
        external
        view
        returns (uint256 riskyAmount, uint256 stableAmount);

    /************************************************
     * View Functions
     ***********************************************/

    /**
     * @notice ParetoManager contract used to specify options
     * @return Address of the ParetoManager contract
     */
    function vaultManager() external view returns (address);

    /**
     * @notice Keeper who manually managers contract
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
