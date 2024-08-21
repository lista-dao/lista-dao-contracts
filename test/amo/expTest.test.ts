import { ethers, network } from 'hardhat';
import { expect } from "chai";
import Decimal from 'decimal.js';


// power = (p - price) / sigma
// e^power
//

describe("ExpTest", function() {
    let expTest;

    this.beforeEach(async function() {
        const ExpTest = await ethers.getContractFactory("ExpTest");
        expTest = await ExpTest.deploy();
        await expTest.waitForDeployment();

        console.log("expTest deployed to:", expTest.target);
    });

    it("test exp, price > 1", async function() {
        const peg = 100000000;
        const prices = [100000000, 101000000, 102000000, 103000000, 104000000, 105000000];
        const sigma1 = 1 * 1000000; // 1e6

        for (let i = 0; i < prices.length; i++) {
            const delta = peg - prices[i];
            const actual = await expTest.exp(delta, sigma1);
          //  console.log(`exp(${delta} / ${sigma1})`);
            const fVal = new Decimal(delta).div(sigma1);
            const expected = new Decimal(Math.E).pow(fVal);
            const one = 170141183460469231731687303715884105728n;
            console.log(actual.toString(), one, expected.toString());
        }
    });

    it.skip("test exp, price < 1", async function() {
        const peg = 100000000;
        const prices = [100000000, 99999999, 98999999, 97999999, 96999999, 95999999];
        const sigma1 = 1 * 1000000; // 1e6

        for (let i = 0; i < prices.length; i++) {
            const delta = peg - prices[i];
            const actual = await expTest.exp_pos(delta, sigma1);
          //  console.log(`exp(${delta} / ${sigma1})`);
            const fVal = new Decimal(delta).div(sigma1);
            const expected = new Decimal(Math.E).pow(fVal);
            console.log(actual.toString(), expected.toString());
        }
    });

});
