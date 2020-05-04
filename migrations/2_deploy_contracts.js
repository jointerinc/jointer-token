var Liquadity = artifacts.require("Liquadity");
//var ISmartToken = artifacts.require("ISmartToken");
// var IContractRegistry = artifacts.require("IContractRegistry");
// var IERC20Token = artifacts.require("IERC20Token");




module.exports = function(deployer) {
  
  //deployer.e

  deployer.deploy(Liquadity,"0x7b3B53Ee4ACbBd634A1b8b722bEE31AE30101877",
                            "0x62bd9d98d4e188e281d7b78e29334969bbe1053c",
                            "0xadb7E96310961E781Cb4f92a7a256dF927c4c301",
                            "0xC7009D32d14B897435675237B8DEF0bb887E4E9A",
                            "0xC00CfEbf530d60F79ebfC5F7AD4c276a1f08b827",
                            "0x13ac687F6987Cc0b4A149145B4E5f87A04290491",
                            "0x66037eFF0f9Bc8a3c51dFd02FB93C09e15613b87",
                            ["0xD368b98d03855835E2923Dc000b3f9c2EBF1b27b","0xDD78D22F53441b6B6216cE69E6dCAe6F7c9252b6","0x62bd9D98d4E188e281D7B78e29334969bbE1053c","0xC7009D32d14B897435675237B8DEF0bb887E4E9A","0xadb7E96310961E781Cb4f92a7a256dF927c4c301"],
                            ["0xadb7E96310961E781Cb4f92a7a256dF927c4c301","0xC7009D32d14B897435675237B8DEF0bb887E4E9A","0x62bd9D98d4E188e281D7B78e29334969bbE1053c"]);
};