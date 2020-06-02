pragma solidity ^0.5.9;

import './IRegistry.sol';
import './UpgradeabilityStorage.sol';

/**
 * @title UpgradeabilityProxy
 * @dev This contract represents a proxy where the implementation address to which it will delegate can be upgraded
 */
contract UpgradeabilityProxy is  UpgradeabilityStorage {
    /**
     * @dev Constructor function
     */
    constructor(uint256 _version) public {
        registry = IRegistry(msg.sender);
        upgradeTo(_version);
    }

    /**
     * @dev Upgrades the implementation to the requested version
     * @param _version representing the version name of the new implementation to be set
     */
    function upgradeTo(uint256 _version) public {
        require(msg.sender == address(registry),"ERR_ONLY_REGISTRERY_CAN_CALL");
        _implementation = registry.getVersion(_version);
    }
}
