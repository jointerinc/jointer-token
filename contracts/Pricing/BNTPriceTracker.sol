pragma solidity ^0.5.9;

import "./provableAPI.sol";
import "../common/Ownable.sol";


contract BNTPriceTracker is usingProvable, Ownable {
    uint256 public priceBNTUSD;

    uint256 public currentGasPrice = 4000000000; //4Gwei

    uint256 public currentGasLimit = 80000;

    string[] public parameters;

    mapping(bytes32 => bool) validIds;

    event LogNewProvableQuery(string description);
    event LogNewEthPriceTicker(uint256 price);
    event LogProof(bytes proof);

    constructor(
        address _systemAddress,
        address _multisigAddress,
        string memory _parameter
    ) public payable Ownable(_systemAddress, _multisigAddress) {
        provable_setCustomGasPrice(currentGasPrice);
        provable_setProof(proofType_Android | proofStorage_IPFS);
        parameters.push(_parameter);
        update(); // Update price on contract creation...
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
        require(msg.sender == provable_cbAddress());
        require(validIds[_myid]);

        priceBNTUSD = parseInt(_result);
        delete validIds[_myid];
        emit LogNewEthPriceTicker(priceBNTUSD);
        emit LogProof(_proof);
    }

    function getCurrencyPrice() external view returns (uint256) {
        return priceBNTUSD;
    }

    function update() public payable {
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
        }
    }

    function() external payable {}

    function withDrawEth(address payable _which) external onlyAuthorized() {
        _which.transfer(address(this).balance);
    }
}
