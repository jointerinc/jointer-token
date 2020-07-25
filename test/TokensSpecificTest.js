const {
  constants,
  expectEvent,
  expectRevert,
  BN,
} = require("@openzeppelin/test-helpers");

const { ZERO_ADDRESS } = constants;

const { expect } = require("chai");

const advanceTime = (time) => {
  return new Promise((resolve, reject) => {
    web3.currentProvider.send(
      {
        jsonrpc: "2.0",
        method: "evm_increaseTime",
        params: [time],
        id: new Date().getTime(),
      },
      (err, result) => {
        if (err) {
          return reject(err);
        }
        return resolve(result);
      }
    );
  });
};

const jntrToken = artifacts.require("MainToken");
const stockToken = artifacts.require("StockToken");
const etnToken = artifacts.require("EtnToken");
const CurrencyPrices = artifacts.require("TestCurrencyPrices");
const AuctionRegisty = artifacts.require("TestAuctionRegistery");
const whiteListContract = artifacts.require("WhiteList");
const WhiteListRegistry = artifacts.require("WhiteListRegistery");

contract("~System works", function (accounts) {
  var JntrToken;
  var StockToken;
  var EtnToken;

  const [
    primaryOwner,
    systemAddress,
    authorityAddress,
    returnTokenPlaceHolder,
    multiSigPlaceHolder,
    accountA,
    accountB,
    accountC,
    vault,
  ] = accounts;
  var registryAddress;
  const etnName = "EtnToken";
  const etnSymbol = "ETN";
  const stockName = "StockToken";
  const stockSymbol = "STOCK";
  const jntrName = "JntrToken";
  const jntrSymbol = "JNTR";

  const etnTokenPrice = 1000000; //1$
  const JntrTokenPrice = 10000; //0.01$
  const stockTokenPrice = 10000000; //10$

  const stockTokenMaturityDays = 3560;
  const tokenMaturityDays = 3560;
  const tokenHoldBackDays = 90;

  //can modify these
  var accountAAmountJntr = 100000;
  var accountBAmountJntr = 50000;

  var accountAAmountStock = 2;
  var amountOfStockTokenSent = 1;
  var transferAmount = 10;
  var approvedAmount = 10;
  var amountOfJntrSent = 10000;

  beforeEach(async function () {
    // let now = (await web3.eth.getBlockNumber("latest")).timestamp;
    // console.log(now);

    this.auctionRegistery = await AuctionRegisty.new(
      systemAddress,
      multiSigPlaceHolder,
      { from: primaryOwner }
    );
    //setup WhiteList
    let flags = 0;
    let maxWallets = 10;

    var whiteListRegistry = await WhiteListRegistry.new(
      systemAddress,
      multiSigPlaceHolder
    );
    let tempWhiteList = await whiteListContract.new();
    await whiteListRegistry.addVersion(1, tempWhiteList.address);
    await whiteListRegistry.createProxy(
      1,
      primaryOwner,
      systemAddress,
      authorityAddress,
      tokenHoldBackDays,
      tokenHoldBackDays,
      tokenHoldBackDays,
      tokenMaturityDays,
      tokenMaturityDays,
      stockTokenMaturityDays
    );
    let proxyAddress = await whiteListRegistry.proxyAddress();
    this.whiteList = await whiteListContract.at(proxyAddress);
    registryAddress = whiteListRegistry.address;

    //add wallets
    await this.whiteList.addNewWallet(accountA, flags, maxWallets, {
      from: systemAddress,
    });
    await this.whiteList.addNewWallet(accountB, flags, maxWallets, {
      from: systemAddress,
    });
    await this.whiteList.addNewWallet(vault, flags, maxWallets, {
      from: systemAddress,
    });
    //add currencyPrices
    this.currencyPrices = await CurrencyPrices.new(
      systemAddress,
      multiSigPlaceHolder,
      { from: primaryOwner }
    );

    //add addresses to the auctionRegistery
    await this.auctionRegistery.registerContractAddress(
      web3.utils.fromAscii("CURRENCY"),
      this.currencyPrices.address,
      {
        from: primaryOwner,
      }
    );
    await this.auctionRegistery.registerContractAddress(
      web3.utils.fromAscii("WHITE_LIST"),
      this.whiteList.address,
      {
        from: primaryOwner,
      }
    );
    await this.auctionRegistery.registerContractAddress(
      web3.utils.fromAscii("VAULT"),
      vault,
      {
        from: primaryOwner,
      }
    );
    //The JNTR token

    JntrToken = await jntrToken.new(
      jntrName,
      jntrSymbol,
      systemAddress,
      authorityAddress,
      this.auctionRegistery.address,
      [accountA, accountB],
      [accountAAmountJntr, accountBAmountJntr],
      {
        from: primaryOwner,
      }
    );
    StockToken = await stockToken.new(
      stockName,
      stockSymbol,
      systemAddress,
      authorityAddress,
      this.auctionRegistery.address,
      returnTokenPlaceHolder,
      [accountA],
      [accountAAmountStock],
      {
        from: primaryOwner,
      }
    );
    EtnToken = await etnToken.new(
      etnName,
      etnSymbol,
      systemAddress,
      authorityAddress,
      this.auctionRegistery.address,
      returnTokenPlaceHolder,
      {
        from: primaryOwner,
      }
    );
    //Add these contracts itself in the whitelist
    //add wallets
    await this.whiteList.addNewWallet(JntrToken.address, flags, maxWallets, {
      from: systemAddress,
    });
    await this.whiteList.addNewWallet(EtnToken.address, flags, maxWallets, {
      from: systemAddress,
    });
    await this.whiteList.addNewWallet(StockToken.address, flags, maxWallets, {
      from: systemAddress,
    });
    //set currency prices
    await this.currencyPrices.setCurrencyPriceUSD(
      [StockToken.address, JntrToken.address, EtnToken.address],
      [stockTokenPrice, JntrTokenPrice, etnTokenPrice],
      { from: systemAddress }
    );
  });
  describe("System should be  initialized correctly", async function () {
    it("has a name", async function () {
      expect(await StockToken.name()).to.equal(stockName);
      expect(await JntrToken.name()).to.equal(jntrName);
      expect(await EtnToken.name()).to.equal(etnName);
    });

    it("has a symbol", async function () {
      expect(await StockToken.symbol()).to.equal(stockSymbol);
      expect(await JntrToken.symbol()).to.equal(jntrSymbol);
      expect(await EtnToken.symbol()).to.equal(etnSymbol);
    });

    it("has 18 decimals", async function () {
      expect(await StockToken.decimals()).to.be.bignumber.equal("18");
      expect(await JntrToken.decimals()).to.be.bignumber.equal("18");
      expect(await EtnToken.decimals()).to.be.bignumber.equal("18");
    });
    it("should premint correctly", async function () {
      expect(await StockToken.balanceOf(accountA)).to.be.bignumber.equal(
        accountAAmountStock.toString()
      );
      expect(await JntrToken.balanceOf(accountA)).to.be.bignumber.equal(
        accountAAmountJntr.toString()
      );
      expect(await JntrToken.balanceOf(accountB)).to.be.bignumber.equal(
        accountBAmountJntr.toString()
      );
    });
  });

  describe("JNTR token should work correctly ", async function () {
    it("should transfer correctly", async function () {
      //before holdback days are over it should fail
      await expectRevert(
        JntrToken.transfer(accountB, transferAmount, { from: accountA }),
        "ERR_TOKEN_HOLDBACK_NOT_OVER"
      );

      await advanceTime(86400 * tokenHoldBackDays);

      let receipt = await JntrToken.transfer(accountB, transferAmount, {
        from: accountA,
      });
      await expectRevert(
        JntrToken.transfer(accountC, transferAmount, { from: accountA }),
        "ERR_TRANSFER_CHECK_WHITELIST"
      );
      //TODO check for events
      expect(await JntrToken.balanceOf(accountA)).to.be.bignumber.equal(
        (accountAAmountJntr - transferAmount).toString()
      );
      expect(await JntrToken.balanceOf(accountB)).to.be.bignumber.equal(
        (accountBAmountJntr + transferAmount).toString()
      );
    });
    it("should approve and transferFrom correctly", async function () {
      // await advanceTime(86400 * tokenHoldBackDays);

      await JntrToken.approve(accountB, approvedAmount, { from: accountA });
      expect(
        await JntrToken.allowance(accountA, accountB)
      ).to.be.bignumber.equal(approvedAmount.toString());

      await expectRevert(
        JntrToken.transferFrom(accountA, accountB, approvedAmount, {
          from: accountB,
        }),
        "ERR_TOKEN_HOLDBACK_NOT_OVER"
      );
      await advanceTime(86400 * tokenHoldBackDays);
      await expectRevert(
        JntrToken.transferFrom(accountA, accountC, approvedAmount, {
          from: accountB,
        }),
        "ERR_TRANSFER_CHECK_WHITELIST"
      );
      await JntrToken.transferFrom(accountA, accountB, approvedAmount, {
        from: accountB,
      });
      expect(await JntrToken.balanceOf(accountA)).to.be.bignumber.equal(
        (accountAAmountJntr - approvedAmount).toString()
      );
      expect(await JntrToken.balanceOf(accountB)).to.be.bignumber.equal(
        (accountBAmountJntr + approvedAmount).toString()
      );
    });
  });
  describe("StockToken should work correctly", async function () {
    it("should be able to buy tokens", async function () {
      //transferFrom of Jntr won't work if tokenHoldbackDays are not over
      await advanceTime(86400 * tokenHoldBackDays);
      //modifier of buytokens
      await StockToken.setExchangeableToken(JntrToken.address, {
        from: systemAddress,
      });
      await JntrToken.approve(StockToken.address, amountOfJntrSent, {
        from: accountB,
      });
      await StockToken.buyTokens(JntrToken.address, amountOfJntrSent, {
        from: accountB,
      });
      let amountOfStockTokens =
        (amountOfJntrSent * JntrTokenPrice) / stockTokenPrice;
      expect(await StockToken.balanceOf(accountB)).to.be.bignumber.equal(
        amountOfStockTokens.toString()
      );
      expect(await JntrToken.balanceOf(accountB)).to.be.bignumber.equal(
        (accountBAmountJntr - amountOfJntrSent).toString()
      );
    });
  });
  describe("EtnToken should work correctly", async function () {
    it("should be able to buy tokens", async function () {
      //transferFrom of Stock won't work if tokenHoldbackDays are not over

      await advanceTime(86400 * tokenHoldBackDays);
      //modifier of buytokens
      await EtnToken.setExchangeableToken(StockToken.address, {
        from: systemAddress,
      });
      await StockToken.approve(EtnToken.address, amountOfStockTokenSent, {
        from: accountA,
      });
      await EtnToken.buyTokens(StockToken.address, amountOfStockTokenSent, {
        from: accountA,
      });
      let amountOfEtnTokens =
        (amountOfStockTokenSent * stockTokenPrice) / etnTokenPrice;
      expect(await EtnToken.balanceOf(accountA)).to.be.bignumber.equal(
        amountOfEtnTokens.toString()
      );
      expect(await StockToken.balanceOf(accountA)).to.be.bignumber.equal(
        (accountAAmountStock - amountOfStockTokenSent).toString()
      );
    });
  });
  describe("Entire Flow works", async function () {
    it("should log absolute values for brevity", async function () {
      //premint balances
      expect(await StockToken.balanceOf(accountA)).to.be.bignumber.equal(
        accountAAmountStock.toString()
      );
      expect(await JntrToken.balanceOf(accountA)).to.be.bignumber.equal(
        accountAAmountJntr.toString()
      );
      expect(await JntrToken.balanceOf(accountB)).to.be.bignumber.equal(
        accountBAmountJntr.toString()
      );
      await advanceTime(86400 * tokenHoldBackDays);
      //JNTR transfer
      await JntrToken.transfer(accountB, transferAmount, { from: accountA });

      expect(await JntrToken.balanceOf(accountA)).to.be.bignumber.equal(
        (accountAAmountJntr - transferAmount).toString()
      );
      expect(await JntrToken.balanceOf(accountB)).to.be.bignumber.equal(
        (accountBAmountJntr + transferAmount).toString()
      );
      accountAAmountJntr = accountAAmountJntr - transferAmount;
      accountBAmountJntr = accountBAmountJntr + transferAmount;
      //JNTR transferfrom
      await JntrToken.approve(accountB, approvedAmount, { from: accountA });
      expect(
        await JntrToken.allowance(accountA, accountB)
      ).to.be.bignumber.equal(approvedAmount.toString());
      await JntrToken.transferFrom(accountA, accountB, approvedAmount, {
        from: accountB,
      });
      expect(await JntrToken.balanceOf(accountA)).to.be.bignumber.equal(
        (accountAAmountJntr - approvedAmount).toString()
      );
      expect(await JntrToken.balanceOf(accountB)).to.be.bignumber.equal(
        (accountBAmountJntr + approvedAmount).toString()
      );
      accountAAmountJntr = accountAAmountJntr - approvedAmount;
      accountBAmountJntr = accountBAmountJntr + approvedAmount;
      //buy Stock
      await StockToken.setExchangeableToken(JntrToken.address, {
        from: systemAddress,
      });
      await JntrToken.approve(StockToken.address, amountOfJntrSent, {
        from: accountB,
      });
      await StockToken.buyTokens(JntrToken.address, amountOfJntrSent, {
        from: accountB,
      });
      let amountOfStockTokens =
        (amountOfJntrSent * JntrTokenPrice) / stockTokenPrice;
      expect(await StockToken.balanceOf(accountB)).to.be.bignumber.equal(
        amountOfStockTokens.toString()
      );
      expect(await JntrToken.balanceOf(accountB)).to.be.bignumber.equal(
        (accountBAmountJntr - amountOfJntrSent).toString()
      );
      //buy ETN
      await EtnToken.setExchangeableToken(StockToken.address, {
        from: systemAddress,
      });

      await StockToken.approve(EtnToken.address, amountOfStockTokenSent, {
        from: accountA,
      });
      await EtnToken.buyTokens(StockToken.address, amountOfStockTokenSent, {
        from: accountA,
      });
      let amountOfEtnTokens =
        (amountOfStockTokenSent * stockTokenPrice) / etnTokenPrice;
      expect(await EtnToken.balanceOf(accountA)).to.be.bignumber.equal(
        amountOfEtnTokens.toString()
      );
      expect(await StockToken.balanceOf(accountA)).to.be.bignumber.equal(
        (accountAAmountStock - amountOfStockTokenSent).toString()
      );
      console.log("accountA\n");

      console.log(
        "StockToken\t" + (await StockToken.balanceOf(accountA)).toString()
      );
      console.log(
        "JntrToken\t" + (await JntrToken.balanceOf(accountA)).toString()
      );
      console.log(
        "EtnToken\t" + (await EtnToken.balanceOf(accountA)).toString()
      );

      console.log("\naccountB\n");

      console.log(
        "StockToken\t" + (await StockToken.balanceOf(accountB)).toString()
      );
      console.log(
        "JntrToken\t" + (await JntrToken.balanceOf(accountB)).toString()
      );
      console.log(
        "EtnToken\t" + (await EtnToken.balanceOf(accountB)).toString()
      );
    });
  });
});
