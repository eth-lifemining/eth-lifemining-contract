// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract Vault {
    mapping(address => uint256) private _vaultLedger;
    address private _challengeAdminAccount;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);

    constructor(address challengeAdminAccount) {
        _challengeAdminAccount = challengeAdminAccount;
    }

    modifier onlyChallenge() {
        require(
            msg.sender == _challengeAdminAccount,
            "Vault: caller is not the challenge contract"
        );
        _;
    }

    function stakeToVault() external payable {
        require(
            msg.value > 0,
            "Vault: staked amount must be greater than zero"
        );

        if (_vaultLedger[msg.sender] == 0) {
            _vaultLedger[msg.sender] = 0;
        }

        _vaultLedger[msg.sender] += msg.value;

        emit Staked(msg.sender, msg.value);
    }

    function unstakeFromVault(
        address payable user,
        uint256 amount
    ) external onlyChallenge {
        // TODO: check; deposit한 만큼만 withdraw할 수 있는 것은 아님
        // require(
        //     _vaultLedger[user] >= amount,
        //     "Vault: insufficient staked amount in vault"
        // );

        user.transfer(amount);

        _vaultLedger[user] -= amount;

        emit Unstaked(user, amount);
    }

    function getStakedAmount(address user) external view returns (uint256) {
        return _vaultLedger[user];
    }
}
