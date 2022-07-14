require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("dotenv").config();

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.2",
        settings: {
          optimizer: { enabled: true, runs: 200 },
        }
      },
      {
        version: "0.8.7",
        settings: {
          optimizer: { enabled: true, runs: 200 },
        }
      }
    ],
  },
  networks: {
    mumbai: {
      url: process.env.MUMBAI_RPC,
      accounts: [ process.env.PRIVATE_KEY ],
      gas: 2100000,
      gasPrice: 8000000000,
    },
    polygon: {
      url: process.env.POLYGON_RPC,
      accounts: [ process.env.PRIVATE_KEY ],
      gas: 5000000
    }
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: {
      polygonMumbai: process.env.MUMBAI_KEY,
      polygon: process.env.POLYGON_KEY
    }
  }
};
