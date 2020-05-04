const {
  constants,
  expectEvent,
  expectRevert,
} = require("@openzeppelin/test-helpers");
const {ZERO_ADDRESS} = constants;

const {expect} = require("chai");
function getParamFromTxEvent(
  transaction,
  paramName,
  contractFactory,
  eventName
) {
  assert.isObject(transaction);
  let logs = transaction.logs;
  if (eventName != null) {
    logs = logs.filter((l) => l.event === eventName);
  }
  assert.equal(logs.length, 1, "too many logs found!");
  let param = logs[0].args[paramName];
  if (contractFactory != null) {
    let contract = contractFactory.at(param);
    assert.isObject(contract, `getting ${paramName} failed for ${param}`);
    return contract;
  } else {
    return param;
  }
}

const AuctionMultiSig = artifacts.require("MultiSigGovernance");
const ERC20 = artifacts.require("TestERC20");
contract("~Multisig works", function (accounts) {
  const args = {
    _bigAmount: 99999999999999,
    _smallAmount: 200,
    _biggerSmallAmount: 300,
    _zero: 0,
  };
  var multiSigIntstance;
  var owners = [accounts[0], accounts[1], accounts[3], accounts[4]];
  const minConfirmationsRequired = 2;

  var data = "0x00";
  let value = 100;
  let destination = accounts[8];
  //console.log(data);

  beforeEach(async function () {
    multiSigIntstance = await AuctionMultiSig.new(
      owners,
      minConfirmationsRequired
    );
    await web3.eth.sendTransaction({
      from: accounts[0],
      to: multiSigIntstance.address,
      value: 1000000,
    });
    let chainId = await web3.eth.net.getId();

    var ERC20Instance = await ERC20.new();
    await ERC20Instance.mint(multiSigIntstance.address, 10000000);

    data = ERC20Instance.contract.methods
      .transfer(accounts[8], 10000)
      .encodeABI();
    value = 0;
    destination = ERC20Instance.address;
  });

  describe("~Multisig works", async function () {
    it("Should return the right public variables", async function () {
      // let owner0 = await multiauthSigIntstance.multiSigOwners(0);
      // assert.equal(owners[0], owner0, "value set correctly");

      // let owner1 = await multiSigIntstance.multiSigOwners(1);
      // assert.equal(owners[1], owner1, "value set correctly");

      let _minConfirmationsRequired = await multiSigIntstance.minConfirmationsRequired();
      assert.equal(
        minConfirmationsRequired,
        _minConfirmationsRequired,
        "value set correctly"
      );
      let _gas = await multiSigIntstance._gas();
      assert.equal(_gas, 34710, "value set correctly");

      for (var i = 0; i < owners.length; i++) {
        let owner = owners[i];

        let _owner = await multiSigIntstance.multiSigOwners(i);
        assert.equal(owner, _owner, "value set correctly");

        let _isOwner = await multiSigIntstance.isOwner(owner);
        assert.equal(_isOwner, true, "value set correctly");

        let ownerIndex = await multiSigIntstance.ownerIndex(owner);
        assert.equal(ownerIndex, i, "value set correctly");
      }
    });
  });
  it("addTransaction should work", async function () {
    // let _transactionCount = await multiSigIntstance.transactionCount();
    let _transactionCount;
    for (var i = 0; i < owners.length; i++) {
      _transactionCount = await multiSigIntstance.transactionCount();
      let addTransaction = await multiSigIntstance.addTransaction(
        destination,
        value,
        data,
        minConfirmationsRequired,
        {from: owners[i]}
      );

      expectEvent(addTransaction, "NewTransactionAdded", {
        transactionId: _transactionCount,
        owner: owners[i],
      });

      let transactionObj = await multiSigIntstance.transactions(
        _transactionCount
      );

      assert.equal(
        transactionObj.destination,
        destination,
        "value set correctly"
      );
      assert.equal(transactionObj.value, value, "value set correctly");
      assert.equal(transactionObj.data, data, "value set correctly");
      assert.equal(transactionObj.executed, false, "value set correctly");
    }
  });

  it("confirmTransaction should work", async function () {
    let _transactionCount = await multiSigIntstance.transactionCount();
    await multiSigIntstance.addTransaction(
      destination,
      value,
      data,
      minConfirmationsRequired,
      {
        from: owners[0],
      }
    );
    let transactionId = _transactionCount;
    for (var i = 1; i < owners.length; i++) {
      let confirmationsCount = await multiSigIntstance.confirmationsCount(
        transactionId
      );

      if (i + 1 > minConfirmationsRequired) {
        await expectRevert(
          multiSigIntstance.confirmTransaction(transactionId, {
            from: owners[i],
          }),
          "ERR_TRAN_ALREADY_EXUCATED"
        );
        continue;
      }
      let confirmTransaction = await multiSigIntstance.confirmTransaction(
        transactionId,
        {from: owners[i]}
      );
      confirmationsCount = await multiSigIntstance.confirmationsCount(
        transactionId
      );

      assert.equal(confirmationsCount, i + 1, "value set correctly");

      expectEvent(confirmTransaction, "TransactionConfirmed", {
        transactionId: transactionId,
        owner: owners[i],
      });

      if (minConfirmationsRequired == confirmationsCount) {
        expectEvent(confirmTransaction, "TransactionExecuted", {
          transactionId: transactionId,
          isSuccess: true,
        });
      }
    }
  });
  it("revoke conifrmation should work", async function () {
    let _transactionCount = await multiSigIntstance.transactionCount();

    let addTransaction = await multiSigIntstance.addTransaction(
      destination,
      value,
      data,
      minConfirmationsRequired,
      {
        from: owners[0],
      }
    );
    let transactionId = _transactionCount;
    for (var i = 1; i < minConfirmationsRequired - 1; i++) {
      let confirmTransaction = await multiSigIntstance.confirmTransaction(
        transactionId,
        {from: owners[i]}
      );
      let confirmationsCount = await multiSigIntstance.confirmationsCount(
        transactionId
      );
    }

    for (var i = minConfirmationsRequired - 2; i > -1; i--) {
      let revokeTransaction = await multiSigIntstance.revokeConfirmation(
        transactionId,
        {from: owners[i]}
      );
      let bool = await multiSigIntstance.confirmations(
        transactionId,
        owners[i]
      );
      assert.equal(bool, false, "confirmation revoked value set correcty");
      expectEvent(revokeTransaction, "TransactionConfirmationRevoked", {
        transactionId: transactionId,
        owner: owners[i],
      });
    }
  });
  it("withdrawEth should work", async function () {
    let amountToWithdraw = 1;
    let oldContractBalance = await web3.eth.getBalance(
      multiSigIntstance.address
    );
    data = multiSigIntstance.contract.methods
      .withDrawEth(amountToWithdraw, owners[0])
      .encodeABI();
    value = 0;
    destination = multiSigIntstance.address;

    let addTransaction = await multiSigIntstance.addTransaction(
      destination,
      value,
      data,
      minConfirmationsRequired,
      {
        from: owners[0],
      }
    );

    let transactionId = getParamFromTxEvent(
      addTransaction,
      "transactionId",
      null,
      "NewTransactionAdded"
    );
    for (var i = 1; i < owners.length; i++) {
      let confirmTransaction = await multiSigIntstance.confirmTransaction(
        transactionId,
        {from: owners[i]}
      );
      let confirmationsCount = await multiSigIntstance.confirmationsCount(
        transactionId
      );

      if (minConfirmationsRequired <= confirmationsCount) {
        var _isSuccess = getParamFromTxEvent(
          confirmTransaction,
          "isSuccess",
          null,
          "TransactionExecuted"
        );

        assert.equal(_isSuccess, true, "Transaction executed successfully");

        break;
      }
    }
    let newContractBalance = await web3.eth.getBalance(
      multiSigIntstance.address
    );

    assert.equal(
      amountToWithdraw,
      oldContractBalance - newContractBalance,
      "withdrawed suceessfully"
    );
  });
});
