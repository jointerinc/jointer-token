"use strict";

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
const ERC20 = artifacts.require("ERC20");

contract("MultiSigTest", function (accounts) {
  const args = {
    _bigAmount: 99999999999999,
    _smallAmount: 200,
    _biggerSmallAmount: 300,
    _zero: 0,
  };
  var multiSigIntstance;
  var owners = [accounts[0], accounts[1], accounts[3], accounts[4]];
  const minConfirmationsRequired = 3;

  var data = "0x00";
  let value = 100;
  let destination = accounts[8];
  //console.log(data);

  beforeEach(async () => {
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

    var ERC20Instance = await ERC20.new("ABC", "TestToken", "1.0.0", chainId);
    await ERC20Instance.mint(multiSigIntstance.address, 10000000);

    data = ERC20Instance.contract.methods
      .transfer(accounts[8], 10000)
      .encodeABI();
    value = 0;
    destination = ERC20Instance.address;
  });

  describe("~Multisig works", function () {
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
    it("addTransaction should work", async function () {
      let _transactionCount = await multiSigIntstance.transactionCount();

      for (var i = 0; i < owners.length; i++) {
        let addTransaction = await multiSigIntstance.addTransaction(
          destination,
          value,
          data,
          minConfirmationsRequired,
          {from: owners[i]}
        );

        let transactionId = getParamFromTxEvent(
          addTransaction,
          "transactionId",
          null,
          "NewTransactionAdded"
        );
        let owner = getParamFromTxEvent(
          addTransaction,
          "owner",
          null,
          "NewTransactionAdded"
        );
        assert.equal(
          _transactionCount.toString(),
          transactionId.toString(),
          "TransactionId emitted correctly"
        );
        // let logs = addTransaction.logs;
        // logs = logs.filter((l) => l.event === "TransactionExecuted");
        // console.log(logs);

        // var emptyArray = [];
        // console.log(emptyArray);

        assert.equal(owner, owners[i], "Owner emitted correctly");
        _transactionCount = await multiSigIntstance.transactionCount();

        let transactionObj = await multiSigIntstance.transactions(
          transactionId
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

        assert.equal(confirmationsCount, i + 1, "value set correctly");

        let _transactionId = getParamFromTxEvent(
          confirmTransaction,
          "transactionId",
          null,
          "TransactionConfirmed"
        );
        // console.log("_transactionId:" + _transactionId);
        // console.log("transactionId:" + transactionId);

        let confirmer = getParamFromTxEvent(
          confirmTransaction,
          "owner",
          null,
          "TransactionConfirmed"
        );

        assert.equal(confirmer, owners[i], "Owner emitted correctly");

        if (minConfirmationsRequired <= confirmationsCount) {
          _transactionId = getParamFromTxEvent(
            confirmTransaction,
            "transactionId",
            null,
            "TransactionExecuted"
          );

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
    });
    it("revoke conifrmation should work", async function () {
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
      for (var i = 1; i < minConfirmationsRequired - 1; i++) {
        let confirmTransaction = await multiSigIntstance.confirmTransaction(
          transactionId,
          {from: owners[i]}
        );
        let confirmationsCount = await multiSigIntstance.confirmationsCount(
          transactionId
        );
        assert.equal(confirmationsCount, i + 1, "value set correctly");

        // let _transactionId = getParamFromTxEvent(
        //   confirmTransaction,
        //   "transactionId",
        //   null,
        //   "TransactionConfirmed"
        // );
        // console.log("_transactionId:" + _transactionId);
        // console.log("transactionId:" + transactionId);

        let confirmer = getParamFromTxEvent(
          confirmTransaction,
          "owner",
          null,
          "TransactionConfirmed"
        );
        // assert.equal(
        //   //some problem here
        //   _transactionId,
        //   transactionId,
        //   "transactionId emitted correctly"
        // );
        assert.equal(confirmer, owners[i], "Owner emitted correctly");
        let bool = await multiSigIntstance.confirmations(
          transactionId,
          owners[i]
        );
        assert.equal(bool, true, "confirmed value set correctly");
      }
      // console.log(await multiSigIntstance.confirmationsCount(transactionId));
      // let bool = await multiSigIntstance.confirmations(
      //   transactionId,
      //   owners[2]
      // );
      // let transactionObj = await multiSigIntstance.transactions(transactionId);
      // console.log(transactionObj);

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
        let revoker = getParamFromTxEvent(
          revokeTransaction,
          "owner",
          null,
          "TransactionConfirmationRevoked"
        );
        assert.equal(revoker, owners[i], "Owner emitted correctly");
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
});
