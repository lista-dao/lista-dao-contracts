// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";

import { AltasOracleAdaptor } from "../../../contracts/oracle/AltasOracleAdaptor.sol";

/**
 * @title DeployAtlasOracleAdaptors
 * @notice Deploys one AltasOracleAdaptor per unique Atlas Oracle push feed
 * Run with:
 *   forge script scripts/prod/oracle/deployAtlasOracleAdaptors.sol:DeployAtlasOracleAdaptors \
 *     --rpc-url $BSC_RPC --broadcast --slow -vvvv
 */
contract DeployAtlasOracleAdaptors is Script {
    struct Feed {
        string symbol;
        address pushContract;
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deployer:", deployer);

        Feed[20] memory feeds = [
            // ----- Feeds 719-731 (new tokens, replacing BinanceOracle) -----
            Feed("B2/USD",     0xd6cF91a4D545462821A43997A6df104c5068D71D), // feed 719
            Feed("B/USD",      0x2BcDFbc731FD179c70794854a4260774369c8d27), // feed 720
            Feed("CDL/USD",    0x5036F6F0b618B5eB12452b9FC782c8D2E5e996c9), // feed 721
            Feed("SPA/USD",    0x9a97167364dD00F8Bc52e346Ccb8d603e0b9A740), // feed 722
            Feed("ASTER/USD",  0xEE9483FD2d380384d42326143f4bc9Bd0513234d), // feed 723
            Feed("AB/USD",     0xfF45B658838fb3Afa2d00CCa5033258C262F98De), // feed 724
            Feed("TAKE/USD",   0x61e4BE67372e5dFF1B8539cc5441B170ede68A48), // feed 725
            Feed("PUFFER/USD", 0x2BC9c150981D74E24b85C3d714852631928599B4), // feed 726
            Feed("WLFI/USD",   0x6eBa8B28f2411AB14f7ecDC3A2477ad436AcbD21), // feed 727
            Feed("OIK/USD",    0xfe9A5337dA82a0fc8476C2A1EDc292d729d29f71), // feed 728
            Feed("AT/USD",     0x8b8678dC64b7539A59E68e25d10cb2846F0918fE), // feed 729
            Feed("EGL1/USD",   0xe659636dbe70E9a53f7762D9eEF385A4fA528475), // feed 730
            Feed("ANKR/USD",   0xEd2ce62b7BFDD31876B1e956a672e8fBE8b29403), // feed 731
            // ----- Shared / additional feeds (used by multiple assets in ResilientOracle) -----
            Feed("FDUSD/USD",  0x122589967CbE77Dd6061D212D198ca45F77fd02c), // feed 732
            Feed("CAKE/USD",   0x55aD1D026D1bC49939b0bA9A451E393c79ad8e93), // feed 733
            Feed("BNB/USD",    0x9C0517F5b4c8657c7F18D68d2d79e2b3b1cd6438), // feed 633
            Feed("ETH/USD",    0x7942b8DD9f552c57Eb94D16ea8215aEf6CAc948f), // feed 632
            Feed("BTCB/USD",   0x4f6c53fb9CdD46269d24bCa4E68bB680879132fc), // feed 626 (also used by solvBTC, SolvBTC.DLP, pumpBTC, mBTC)
            Feed("USDT/USD",   0x9Fc000FC9C17578b49853278A517e357201D01e4), // feed 649 (also used by USDF)
            Feed("USDe/USD",   0x802694092E220AD7C180AC8572B6148B2F409be6)  // feed 638
        ];

        vm.startBroadcast(deployerPrivateKey);

        for (uint256 i = 0; i < feeds.length; i++) {
            AltasOracleAdaptor adaptor = new AltasOracleAdaptor(feeds[i].pushContract);
            console.log("AltasOracleAdaptor", feeds[i].symbol, "->", address(adaptor));
            console.log("  underlying Atlas feed:", feeds[i].pushContract);
        }

        vm.stopBroadcast();
    }
}
