// It is broken because of structure change in the whiteList. Will updtae soon
const {
  constants,
  expectEvent,
  expectRevert,
} = require("@openzeppelin/test-helpers");
const { ZERO_ADDRESS } = constants;

const { expect } = require("chai");

const whiteListContract = artifacts.require("WhiteList");
const WhiteListRegistry = artifacts.require("WhiteListRegistery");
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

contract("~WhiteList works", function (accounts) {
  const [
    primaryOwner,
    authorityAddress,
    systemAddress,
    toBeWhiteListed,
    extraAddedWallet,
    fromChina,
    fromEU,
    bypassedAddress,
    multiSigPlaceHolder,
    other1,
  ] = accounts;
  var registryAddress;
  const stockTokenMaturityDays = 3560;
  const tokenMaturityDays = 0;
  const tokenHoldBackDays = 90;

  var txTimestamp;
  const KYC = 1 << 0; //0x01
  const AML = 1 << 1; //0x02
  const ACCREDIATED_INVESTOR = 1 << 2;
  const QUALIFIED_INVESTOR = 1 << 3;
  const RETAIL_INVESTOR = 1 << 4;
  const IS_ALLOWED_BUYBACK = 1 << 5;
  const DECENTRALIZE_EXCHANGE = 1 << 6; // wallet of decentralize exchanges
  const CENTRALIZE_EXCHANGE = 1 << 7; // wallet of centralize exchanges
  const IS_ALLOWED_ETN = 1 << 8;
  const IS_ALLOWED_STOCK = 1 << 9;
  const FROM_USA = 1 << 10;
  const FROM_CHINA = 1 << 11;
  const FROM_EU = 1 << 12;
  const IS_BYPASSED = 1 << 13;

  var mapString = new Map([
    ["KYC", 0],
    ["AML", 1],
    ["ACCREDIATED_INVESTOR", 2],
    ["QUALIFIED_INVESTOR", 3],
    ["RETAIL_INVESTOR", 4],
    ["IS_ALLOWED_BUYBACK", 5],
    ["DECENTRALIZE_EXCHANGE", 6],
    ["CENTRALIZE_EXCHANGE", 7],
    ["IS_ALLOWED_ETN", 8],
    ["IS_ALLOWED_STOCK", 9],
    ["FROM_USA", 10],
    ["FROM_CHINA", 11],
    ["FROM_EU", 12],
    ["IS_BYPASSED", 13],
  ]);

  const convertDaysToTimeStamp = function (days) {
    if (days == 0) return 0;
    let duration = 86400 * days;
    return txTimestamp + duration;
  };
  const calculateMaskAndCondition = function (flagsString, bools) {
    let mask = 0;
    let conditon = 0;
    for (let i = 0; i < flagsString.length; i++) {
      let bitPlace = mapString.get(flagsString[i]);

      mask = mask | (1 << bitPlace);
      if (bools[i] == true) {
        conditon = conditon | (1 << bitPlace);
      } else {
        conditon = conditon | (0 << bitPlace);
      }
    }
    return [mask, conditon];
  };

  beforeEach(async function () {
    var whiteListRegistry = await WhiteListRegistry.new(
      systemAddress,
      multiSigPlaceHolder
    );
    let tempWhiteList = await whiteListContract.new();
    await whiteListRegistry.addVersion(1, tempWhiteList.address);

    txTimestamp = (await web3.eth.getBlock("latest")).timestamp;
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
  });
  it("should initialize properly", async function () {
    expect(await this.whiteList.primaryOwner()).to.equal(primaryOwner);
    expect(await this.whiteList.authorityAddress()).to.equal(authorityAddress);
    expect(await this.whiteList.systemAddress()).to.equal(systemAddress);
  });
  it("should add New wallet correctly by system only", async function () {
    let flags = KYC | AML;
    let maxWallets = 10;
    await expectRevert(
      this.whiteList.addNewWallet(toBeWhiteListed, flags, maxWallets, {
        from: other1,
      }),
      "ERR_AUTHORIZED_ADDRESS_ONLY"
    );
    await expectRevert(
      this.whiteList.addNewWallet(ZERO_ADDRESS, flags, maxWallets, {
        from: systemAddress,
      }),
      "ERR_ZERO_ADDRESS"
    );
    let receipt = await this.whiteList.addNewWallet(
      toBeWhiteListed,
      flags,
      maxWallets,
      {
        from: systemAddress,
      }
    );

    expectEvent(receipt, "AccountWhiteListed", {
      which: toBeWhiteListed,
      flags: flags.toString(),
    });

    //revert if address already whiteListed
    await expectRevert(
      this.whiteList.addNewWallet(toBeWhiteListed, flags, maxWallets, {
        from: systemAddress,
      }),
      "ERR_ACTION_NOT_ALLOWED"
    );
    expect(await this.whiteList.address_belongs(toBeWhiteListed)).to.equal(
      toBeWhiteListed
    );
    //is WhiteListed
    expect(await this.whiteList.isWhiteListed(toBeWhiteListed)).to.equal(true);

    //details set correctly
    let details = await this.whiteList.user_details(toBeWhiteListed);
    expect(details.flags.toString()).to.equal(flags.toString());
    expect(details.maxWallets.toString()).to.equal(maxWallets.toString());
  });
  it("should update max wallets correctly by owner only", async function () {
    let flags = KYC | AML;
    let maxWallets = 10;
    let updatedMaxWallets = 1;
    await this.whiteList.addNewWallet(toBeWhiteListed, flags, maxWallets, {
      from: systemAddress,
    });
    await expectRevert(
      this.whiteList.updateMaxWallet(toBeWhiteListed, updatedMaxWallets, {
        from: other1,
      }),
      "ERR_AUTHORIZED_ADDRESS_ONLY"
    );
    //cannot update if account is not whitelisted
    await expectRevert(
      this.whiteList.updateMaxWallet(other1, updatedMaxWallets, {
        from: systemAddress,
      }),
      "ERR_AUTHORIZED_ADDRESS_ONLY"
    );
    await this.whiteList.updateMaxWallet(toBeWhiteListed, updatedMaxWallets, {
      from: primaryOwner,
    });
    let details = await this.whiteList.user_details(toBeWhiteListed);
    expect(details.maxWallets.toString()).to.equal(
      updatedMaxWallets.toString()
    );
  });
  it("should add more wallets correctly", async function () {
    let flags = KYC | AML;
    let maxWallets = 1;
    await this.whiteList.addNewWallet(toBeWhiteListed, flags, maxWallets, {
      from: systemAddress,
    });
    await expectRevert(
      this.whiteList.addMoreWallets(ZERO_ADDRESS, {
        from: toBeWhiteListed,
      }),
      "ERR_ZERO_ADDRESS"
    );
    await expectRevert(
      this.whiteList.addMoreWallets(extraAddedWallet, {
        from: other1,
      }),
      "ERR_AUTHORIZED_ADDRESS_ONLY"
    );

    let receipt = await this.whiteList.addMoreWallets(extraAddedWallet, {
      from: toBeWhiteListed,
    });

    await expectRevert(
      this.whiteList.addMoreWallets(other1, {
        from: toBeWhiteListed,
      }),
      "ERR_MAXIMUM_WALLET_LIMIT"
    );
    expectEvent(receipt, "WalletAdded", {
      from: toBeWhiteListed,
      which: extraAddedWallet,
    });
    //let details = await this.whiteList.user_details(toBeWhiteListed);
    //Do we need getUserWallets Function???
    //expect(details.wallets[0]).to.equal(extraAddedWallet);

    expect(await this.whiteList.address_belongs(extraAddedWallet)).to.equal(
      toBeWhiteListed
    );
    //is WhiteListed
    expect(await this.whiteList.isWhiteListed(extraAddedWallet)).to.equal(true);
  });
  it("should change flags correctly by system only", async function () {
    let flags = KYC | AML;
    let changedFlags = KYC | AML | FROM_EU;
    let maxWallets = 1;
    await this.whiteList.addNewWallet(toBeWhiteListed, flags, maxWallets, {
      from: systemAddress,
    });
    await expectRevert(
      this.whiteList.changeFlags(toBeWhiteListed, changedFlags, {
        from: other1,
      }),
      "ERR_AUTHORIZED_ADDRESS_ONLY"
    );
    //if not whitelisted
    await expectRevert(
      this.whiteList.changeFlags(other1, changedFlags, { from: systemAddress }),
      "ERR_ACTION_NOT_ALLOWED"
    );
    let receipt = await this.whiteList.changeFlags(
      toBeWhiteListed,
      changedFlags,
      {
        from: systemAddress,
      }
    );
    expectEvent(receipt, "FlagsChanged", {
      which: toBeWhiteListed,
      flags: changedFlags.toString(),
    });

    let details = await this.whiteList.user_details(toBeWhiteListed);
    expect(details.flags.toString()).to.equal(changedFlags.toString());
  });

  it("Should add reciveing rule correctly only by system", async function () {
    let flags = KYC;
    let maxWallets = 1;
    await this.whiteList.addNewWallet(toBeWhiteListed, flags, maxWallets, {
      from: systemAddress,
    });
    let flagsString = ["KYC", "AML"];
    let bools = [true, false];
    let [mask, condition] = calculateMaskAndCondition(flagsString, bools);

    await expectRevert(
      this.whiteList.addMainRecivingRule(mask, condition, {
        from: other1,
      }),
      "ERR_AUTHORIZED_ADDRESS_ONLY"
    );
    await this.whiteList.addMainRecivingRule(mask, condition, {
      from: systemAddress,
    });

    let reciveingRule = await this.whiteList.tokenToReceivingRule(0);

    expect(reciveingRule[0].toString()).to.equal(mask.toString());
    expect(reciveingRule[1].toString()).to.equal(condition.toString());

    flagsString = ["KYC", "AML", "FROM_EU"];
    bools = [true, false, true];
    [mask, condition] = calculateMaskAndCondition(flagsString, bools);

    await this.whiteList.addMainRecivingRule(mask, condition, {
      from: systemAddress,
    });

    reciveingRule = await this.whiteList.tokenToReceivingRule(0);
    expect(reciveingRule[0].toString()).to.equal(mask.toString());
    expect(reciveingRule[1].toString()).to.equal(condition.toString());
  });
  it("should check reciving rule correctly", async function () {
    let flags = KYC | AML | FROM_CHINA;
    let maxWallets = 1;
    await this.whiteList.addNewWallet(fromChina, flags, maxWallets, {
      from: systemAddress,
    });
    flags = KYC | AML | FROM_EU;
    await this.whiteList.addNewWallet(fromEU, flags, maxWallets, {
      from: systemAddress,
    });

    let flagsString = ["KYC", "AML", "FROM_CHINA"];
    let bools = [true, true, false];
    let [mask, condition] = calculateMaskAndCondition(flagsString, bools);
    await this.whiteList.addMainRecivingRule(mask, condition, {
      from: systemAddress,
    });

    expect(await this.whiteList.main_isReceiveAllowed(fromChina)).to.equal(
      false
    );
    expect(await this.whiteList.main_isReceiveAllowed(fromEU)).to.equal(true);
  });
  it("should add and remove transferring rules correctly by system only", async function () {
    let flagsStrings = ["FROM_EU"];
    let bools = [true];
    let [from_mask, from_condition] = calculateMaskAndCondition(
      flagsStrings,
      bools
    );
    flagsString = ["FROM_CHINA"];
    bools = [true];
    [to_mask, to_condition] = calculateMaskAndCondition(flagsString, bools);
    await expectRevert(
      this.whiteList.addMainTransferringRule(
        from_mask,
        from_condition,
        to_mask,
        to_condition,
        {
          from: other1,
        }
      ),
      "ERR_AUTHORIZED_ADDRESS_ONLY"
    );
    await this.whiteList.addMainTransferringRule(
      from_mask,
      from_condition,
      to_mask,
      to_condition,
      {
        from: systemAddress,
      }
    );
    let transferringRule = await this.whiteList.tokenToTransferringRuleArray(
      0,
      0
    );
    expect(transferringRule[0].toString()).to.equal(from_mask.toString());
    expect(transferringRule[1].toString()).to.equal(from_condition.toString());
    expect(transferringRule[2].toString()).to.equal(to_mask.toString());
    expect(transferringRule[3].toString()).to.equal(to_condition.toString());

    flagsString = ["CENTRALIZE_EXCHANGE"];
    bools = [true];
    [from_mask, from_condition] = calculateMaskAndCondition(flagsString, bools);
    flagsString = ["DECENTRALIZE_EXCHANGE"];
    bools = [true];
    [to_mask, to_condition] = calculateMaskAndCondition(flagsString, bools);

    await this.whiteList.addMainTransferringRule(
      from_mask,
      from_condition,
      to_mask,
      to_condition,
      {
        from: systemAddress,
      }
    );
    transferringRule = await this.whiteList.tokenToTransferringRuleArray(0, 1);
    expect(transferringRule[0].toString()).to.equal(from_mask.toString());
    expect(transferringRule[1].toString()).to.equal(from_condition.toString());
    expect(transferringRule[2].toString()).to.equal(to_mask.toString());
    expect(transferringRule[3].toString()).to.equal(to_condition.toString());

    await expectRevert(
      this.whiteList.removeMainTransferingRules(1, { from: other1 }),
      "ERR_AUTHORIZED_ADDRESS_ONLY"
    );
    this.whiteList.removeMainTransferingRules(1, { from: systemAddress });
    await expectRevert.unspecified(
      this.whiteList.tokenToTransferringRuleArray(0, 1)
    );
  });
  it("Should Check Transfer Rules Correctly", async function () {
    //add recieve rules
    let flagsString = ["KYC", "AML"];
    let bools = [true, true];
    let [mask, condition] = calculateMaskAndCondition(flagsString, bools);

    await this.whiteList.addMainRecivingRule(mask, condition, {
      from: systemAddress,
    });
    //add transferring Rules
    flagsStrings = ["FROM_EU"];
    bools = [true];
    [from_mask, from_condition] = calculateMaskAndCondition(
      flagsStrings,
      bools
    );
    flagsString = ["FROM_CHINA"];
    bools = [true];
    [to_mask, to_condition] = calculateMaskAndCondition(flagsString, bools);

    await this.whiteList.addMainTransferringRule(
      from_mask,
      from_condition,
      to_mask,
      to_condition,
      {
        from: systemAddress,
      }
    );
    //a bypassed address
    flags = IS_BYPASSED;
    maxWallets = 1;
    await this.whiteList.addNewWallet(bypassedAddress, flags, maxWallets, {
      from: systemAddress,
    });
    flags = KYC | AML | FROM_CHINA;
    await this.whiteList.addNewWallet(fromChina, flags, maxWallets, {
      from: systemAddress,
    });
    flags = KYC | AML | FROM_EU;
    await this.whiteList.addNewWallet(fromEU, flags, maxWallets, {
      from: systemAddress,
    });
    flags = AML;
    await this.whiteList.addNewWallet(other1, flags, maxWallets, {
      from: systemAddress,
    });

    //should return true if address  "to" is  bypassed
    expect(
      await this.whiteList.main_isTransferAllowed(
        other1,
        other1,
        bypassedAddress
      )
    ).to.equal(true);
    //should return true if msg.sender is bypassed and to is whitelisted else return false
    //extraAddedwallet is not whitelisted right now
    expect(
      await this.whiteList.main_isTransferAllowed(
        bypassedAddress,
        bypassedAddress,
        other1
      )
    ).to.equal(true);
    expect(
      await this.whiteList.main_isTransferAllowed(
        bypassedAddress,
        bypassedAddress,
        extraAddedWallet
      )
    ).to.equal(false);

    //revert if receiving rules is not satisfied
    await expectRevert(
      this.whiteList.main_isTransferAllowed(fromEU, fromEU, extraAddedWallet),
      "ERR_TRANSFER_CHECK_WHITELIST"
    );

    //revert if holdback days are not over
    await expectRevert(
      this.whiteList.main_isTransferAllowed(fromEU, fromEU, fromChina),
      "ERR_TOKEN_HOLDBACK_NOT_OVER"
    );
    await advanceTime(86400 * tokenHoldBackDays);
    flags = KYC | AML;
    await this.whiteList.changeFlags(other1, flags, {
      from: systemAddress,
    });

    //should return false if transferRules are met
    expect(
      await this.whiteList.main_isTransferAllowed(fromEU, fromEU, fromChina)
    ).to.equal(false);

    expect(
      await this.whiteList.main_isTransferAllowed(fromEU, fromEU, fromChina)
    ).to.equal(false);

    //should be able to transfer
    expect(
      await this.whiteList.main_isTransferAllowed(fromEU, fromEU, other1)
    ).to.equal(true);

    // //should throw if token is matured
    await advanceTime(86400 * stockTokenMaturityDays);
    //need to do this to reflect the timechange
    flags = KYC | AML;
    await this.whiteList.changeFlags(other1, flags, {
      from: systemAddress,
    });
    await expectRevert(
      this.whiteList.stock_isTransferAllowed(fromEU, fromEU, other1),
      "ERR_TOKEN_MATURED"
    );
  });
});
