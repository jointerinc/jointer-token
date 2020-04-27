pragma solidity ^0.5.9;

import "../common/RegisteryOwnable.sol";
import "../common/SafeMath.sol";

contract AuctionRegistery is RegisteryOwnable,SafeMath {
    
    
    mapping(bytes32 => address) private contractAddress;

    mapping(bytes32 => uint256) public contractIndex;

    string[] public contracts;

    event ContractAddressUpdated(
        bytes32 indexed _contractName,
        address _contractAddressFrom,
        address _contractAddressTo
    );

    constructor(address _systemAddess, address _multisig)
        public
        RegisteryOwnable(_systemAddess, _multisig)
    {
        
    }

    function contractsCount() external view returns (uint256) {
        return contracts.length;
    }

    function getAddressOf(bytes32 _contractName) external view returns (address) {
        return contractAddress[_contractName];
    }
    
    
    /**
      * @dev add new contarct address to the registery 
      * @return bool
    */
    function registerContractAddress(bytes32 _contractName, address _contractAddress)
        external
        onlyOneOfOnwer()
        notZeroValue(_contractName.length)
        notZeroAddress(_contractAddress)
        returns (bool)
    {
        require(contractAddress[_contractName] == address(0), ERR_SAME_ADDRESS);
        
        contractAddress[_contractName] = _contractAddress;
        
        contractIndex[_contractName] = contracts.length;
        
        contracts.push(bytes32ToString(_contractName));
        
        emit ContractAddressUpdated(_contractName,address(0),_contractAddress);
        
        return true;
    }
    
    
    
   /**
      * @dev update contarct address to the registery 
      * note that we dont need to update contractAddress index we just update contract addres only
      * @return bool
    */
    function updateContractAddress(bytes32 _contractName, address _contractAddress) 
        external
        onlyAuthorized()
        notZeroValue(_contractName.length)
        notZeroAddress(_contractAddress)
        notZeroAddress(contractAddress[_contractName])
        returns (bool)
    {   
        emit ContractAddressUpdated(_contractName,contractAddress[_contractName],_contractAddress);
        contractAddress[_contractName] = _contractAddress;
        return true;
    }
    
    
    /**
      * @dev remove contarct address to the registery 
      * @return bool
    */
    function removeContractAddress(bytes32 _contractName)
        external
        onlyAuthorized()
        notZeroValue(_contractName.length)
        notZeroAddress(contractAddress[_contractName])
        returns (bool)
    {   
        
        uint256 _contractIndex = contractIndex[_contractName];
        
        string memory lastContract = contracts[safeSub(contracts.length,1)];
        
        bytes32 lastContractBytes = stringToBytes32(lastContract);
        
        contracts[ _contractIndex] = lastContract;
        
        contractIndex[lastContractBytes] = _contractIndex;
        
        emit ContractAddressUpdated(_contractName,contractAddress[_contractName],address(0));
        
        delete contractAddress[_contractName];
        
        delete contractIndex[_contractName];
        
        delete contracts[safeSub(contracts.length,1)];
        
        return true;
    }
    
    
    
    
     /**
      * @dev utility, converts bytes32 to a string
      * note that the bytes32 argument is assumed to be UTF8 encoded ASCII string
      * 
      * @return string representation of the given bytes32 argument
    */
    function bytes32ToString(bytes32 _bytes) public pure returns (string memory) {
        bytes memory byteArray = new bytes(32);
        for (uint256 i; i < 32; i++) {
            byteArray[i] = _bytes[i];
        }

        return string(byteArray);
    }

    /**
      * @dev utility, converts string to bytes32
      * note that the bytes32 argument is assumed to be UTF8 encoded ASCII string
      * 
      * @return string representation of the given bytes32 argument
    */
    function stringToBytes32(string memory _string) public pure returns (bytes32) {
        bytes32 result;
        assembly {
            result := mload(add(_string,32))
        }
        return result;
    }
}
