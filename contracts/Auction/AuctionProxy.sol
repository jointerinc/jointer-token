pragma solidity ^0.5.9;

import "../Proxy/IRegistry.sol";
import "../common/Ownable.sol";
import "../Proxy/UpgradeabilityProxy.sol";
import "../InterFaces/IERC20Token.sol";

interface InitializeInterface {
    function initialize(
        uint256 _startTime,
        uint256 _minAuctionTime,
        uint256 _interval,
        address _primaryOwner,
        address _systemAddress,
        address _multisigAddress,
        address _registeryAddress
    ) external;
}

/**
 * @title Registry
 * @dev This contract works as a registry of versions, it holds the implementations for the registered versions.
 */
contract AuctionRegistry is Ownable, IRegistry {
    // Mapping of versions to implementations of different functions
    mapping(uint256 => address) internal versions;

    uint256 public currentVersion;

    address payable public proxyAddress;

    //@dev constructor
    //@param _systemAddress address of the system Owner
    constructor(address _systemAddress, address _multisigAddress)
        public
        Ownable(_systemAddress, _multisigAddress)
    {}

    /**
     * @dev Registers a new version with its implementation address
     * @param version representing the version name of the new implementation to be registered
     * @param implementation representing the address of the new implementation to be registered
     */
    function addVersion(uint256 version, address implementation)
        public
        onlyOneOfOnwer()
        notZeroAddress(implementation)
    {
        require(
            versions[version] == address(0),
            "This version has implementation attached"
        );
        versions[version] = implementation;
        emit VersionAdded(version, implementation);
    }

    /**
     * @dev Tells the address of the implementation for a given version
     * @param version to query the implementation of
     * @return address of the implementation registered for the given version
     */
    function getVersion(uint256 version) public view returns (address) {
        return versions[version];
    }

    /**
     * @dev Creates an upgradeable proxy
     * @param version representing the first version to be set for the proxy
     * @return address of the new proxy created
     */
    function createProxy(
        uint256 version,
        uint256 _startTime,
        uint256 _minAuctionTime,
        uint256 _interval,
        address _primaryOwner,
        address _systemAddress,
        address _multisigAddress,
        address _registeryAddress
    ) external onlyOneOfOnwer() returns (address) {
        require(proxyAddress == address(0), "ERR_PROXY_ALREADY_CREATED");

        UpgradeabilityProxy proxy = new UpgradeabilityProxy(version);

        InitializeInterface(address(proxy)).initialize(
            _startTime,
            _minAuctionTime,
            _interval,
            _primaryOwner,
            _systemAddress,
            _multisigAddress,
            _registeryAddress
        );

        currentVersion = version;
        proxyAddress = address(proxy);
        emit ProxyCreated(address(proxy));
        return address(proxy);
    }

    /**
     * @dev Upgrades the implementation to the requested version
     * @param version representing the version name of the new implementation to be set
     */

    function upgradeTo(uint256 version) public onlyAuthorized() returns (bool) {
        currentVersion = version;
        UpgradeabilityProxy(proxyAddress).upgradeTo(version);
        return true;
    }
}
