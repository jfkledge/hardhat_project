import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers, upgrades } from 'hardhat';
import chalk from 'chalk';

const deployFundManager: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { log } = deployments;

  const { deployer } = await getNamedAccounts();
  log(chalk.green(`Deployer: ${deployer}`));

  log(chalk.blue(`Deploying DeFundManager (UUPS)...`));

  const FundManagerFactory = await ethers.getContractFactory('FundManager');
  const proxy = await upgrades.deployProxy(FundManagerFactory, [], {
    kind: 'uups',
    initializer: 'initialize',
  });

  await proxy.waitForDeployment();

  const proxyAddress = await proxy.getAddress();
  log(chalk.yellow(`✅ FundManager deployed at proxy address: ${proxyAddress}`));
  await deployments.save('FundManager', {
    address: proxyAddress,
    abi: JSON.parse(FundManagerFactory.interface.formatJson()),
  });
};

export default deployFundManager;
deployFundManager.tags = ['FundManager'];
