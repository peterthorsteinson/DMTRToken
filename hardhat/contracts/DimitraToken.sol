// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract DimitraToken is ERC20PresetMinterPauser {
    uint private immutable _cap;
    bytes32 private constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
  
    // Change visibility to private
    mapping (address => mapping(uint => uint)) private LockBoxMap; // Mapping of user => vestingDay => amount
    mapping (address => uint[]) private userReleaseTime; // user => vestingDays
    uint[] private updatedReleaseTimes;
    uint private totalLockBoxBalance;

    event LogIssueLockedTokens(address sender, address recipient, uint amount, uint releaseTimeStamp);

    constructor() ERC20PresetMinterPauser("Dimitra Token", "DMTR") {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _cap = 1000000000 * (10 ** uint(decimals())); // Cap limit set to 1 billion tokens
        _setupRole(ISSUER_ROLE,_msgSender());
    }

    function cap() public view returns (uint) {
        return _cap;
    }

    function mint(address account, uint256 amount) public virtual override {
        require(ERC20.totalSupply() + amount <= cap(), "DimitraToken: cap exceeded");
        _mint(account, amount);
    }

    function issueLockedTokens(address recipient, uint lockAmount, uint releaseTimeStamp) public { // Send the mature date by calculating if from the FrontEnd
        require(hasRole(ISSUER_ROLE, _msgSender()), "DimitraToken: must have issuer role to issue locked tokens");
        require(releaseTimeStamp >= block.timestamp, "DimitraToken: Release time should be greater than current block time"); // release time stamp must be at least 24 hours from now

        LockBoxMap[recipient][releaseTimeStamp] += lockAmount;
        totalLockBoxBalance += lockAmount;
        userReleaseTime[recipient].push(releaseTimeStamp);

        emit LogIssueLockedTokens(msg.sender, recipient, lockAmount, releaseTimeStamp);
        _transfer(_msgSender(), recipient, lockAmount);
    }

    function transfer(address recipient,uint amount) public override returns (bool) {
        address sender = _msgSender();
        uint[] memory releaseTimes = userReleaseTime[sender];
        uint arrLength = releaseTimes.length;
        uint lockedAmount;
        
        delete updatedReleaseTimes;
        
        if(arrLength != 0){
            for (uint i = 0; i < arrLength; i++){  // Releasing all tokens
                if(block.timestamp <= releaseTimes[i]){
                    lockedAmount += LockBoxMap[sender][releaseTimes[i]];
                } else {
                    totalLockBoxBalance -= LockBoxMap[sender][userReleaseTime[sender][i]];
                    delete LockBoxMap[sender][userReleaseTime[sender][i]];
                    delete userReleaseTime[sender][i];
                }
            }

            for (uint i = 0; i < arrLength; i++){
                if (userReleaseTime[sender][i] != 0){
                    updatedReleaseTimes.push(userReleaseTime[sender][i]);
                }
            }
            userReleaseTime[sender] = updatedReleaseTimes;
        }

        require(balanceOf(sender) - lockedAmount >= amount, "DimitraToken: Insufficient balance");
        _transfer(sender, recipient, amount);
        return true;
    }

    function getLockedBalance(address sender) public view returns (uint){
        uint userLockBoxBalance = 0;
        uint[] memory releaseTimes = userReleaseTime[sender];
        uint arrLength = releaseTimes.length;
         if(arrLength != 0){
            for (uint i = 0; i < arrLength; i++){
                if(block.timestamp <= releaseTimes[i]){ // There can be a possibility where user has not released it using transfer function
                    userLockBoxBalance += LockBoxMap[sender][releaseTimes[i]];
                }
            }
         }

         return userLockBoxBalance;
    }

    function getTotalLockedBoxBalance() public view returns (uint) {
        return totalLockBoxBalance;
    }
}
