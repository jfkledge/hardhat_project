import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers, upgrades } from 'hardhat';
import chalk from 'chalk';

const deployProjectManager: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { log } = deployments;

  const { deployer } = await getNamedAccounts();
  log(chalk.green(`Deployer: ${deployer}`));

  log(chalk.blue(`Deploying ProjectManager (UUPS)...`));

  const ProjectManagerFactory = await ethers.getContractFactory('ProjectManager');
  const proxy = await upgrades.deployProxy(ProjectManagerFactory, [], {
    kind: 'uups',
    initializer: 'initialize',
  });

  await proxy.waitForDeployment();

  const proxyAddress = await proxy.getAddress();
  log(chalk.yellow(`✅ ProjectManagerFactory deployed at proxy address: ${proxyAddress}`));
  await deployments.save('ProjectManager', {
    address: proxyAddress,
    abi: JSON.parse(ProjectManagerFactory.interface.formatJson()),
  });
};

export default deployProjectManager;
deployProjectManager.tags = ['projectmanager'];
