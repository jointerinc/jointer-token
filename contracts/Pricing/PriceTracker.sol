pragma solidity ^0.5.9;

import "./provableAPI.sol";
import "../common/Ownable.sol";

contract CurrencyPriceTicker is usingProvable, Ownable {
    string public currency;

    uint256 public priceUSD;

    uint256 public currentGasPrice = 12000000000; //12Gwei

    uint256 public currentGasLimit = 100000;

    string[] public parameters;

    bytes32[] public queryIds;

    mapping(bytes32 => bool) validIds;

    event LogNewProvableQuery(string description);
    event LogNewEthPriceTicker(uint256 price);
    event LogProof(bytes proof);

    constructor(
        string memory _currency,
        address _systemAddress,
        address _multisigAddress,
        string memory _parameter
    ) public payable Ownable(_systemAddress, _multisigAddress) {
        currency = _currency;
        provable_setCustomGasPrice(currentGasPrice);
        provable_setProof(proofType_Android | proofStorage_IPFS);
        parameters.push(_parameter);
    }

    function setGasPrice(uint256 _gasPrice) external onlySystem() {
        provable_setCustomGasPrice(_gasPrice);
        currentGasPrice = _gasPrice;
    }

    function setGasLimit(uint256 _gasLimit) external onlySystem() {
        currentGasLimit = _gasLimit;
    }

    function updateParameter(string calldata _parameter)
        external
        onlyAuthorized()
    {
        parameters[0] = _parameter;
    }

    function __callback(
        bytes32 _myid,
        string memory _result,
        bytes memory _proof
    ) public {
        require(msg.sender == provable_cbAddress(),ERR_AUTHORIZED_ADDRESS_ONLY);
        require(validIds[_myid],"ERR_NOT_VALID_ID");

        priceUSD = parseInt(_result);
        delete validIds[_myid];
        emit LogNewEthPriceTicker(priceUSD);
        emit LogProof(_proof);
    }

    function getCurrencyPrice() external view returns (uint256) {
        return priceUSD;
    }

    function update() external payable {
        uint256 fee = provable_getPrice("computation", currentGasLimit);

        if (msg.sender != systemAddress) {
            require(
                msg.value >= fee,
                "If user wants to call this they have to pay price for update"
            );
        }

        if (fee > address(this).balance) {
            emit LogNewProvableQuery(
                "Provable query was NOT sent, please add some ETH to cover for the query fee!"
            );
        } else {
            emit LogNewProvableQuery(
                "Provable query was sent, standing by for the answer..."
            );
            bytes32 queryId = provable_query(
                "computation",
                parameters,
                currentGasLimit
            );
            validIds[queryId] = true;
            queryIds.push(queryId);
        }
    }

    function() external payable {}

    function withDrawEth(address payable _which) external onlyAuthorized() {
        _which.transfer(address(this).balance);
    }
}
