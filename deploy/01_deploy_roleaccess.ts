import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers, upgrades } from 'hardhat';
import chalk from 'chalk';

const deployRoleAccess: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { log } = deployments;

  const { deployer } = await getNamedAccounts();
  log(chalk.green(`Deployer: ${deployer}`));

  log(chalk.blue(`Deploying RoleAccess (UUPS)...`));

  const RoleAccessFactory = await ethers.getContractFactory('RoleAccess');
  const proxy = await upgrades.deployProxy(RoleAccessFactory, [], {
    kind: 'uups',
    initializer: 'initialize',
  });

  await proxy.waitForDeployment();

  const proxyAddress = await proxy.getAddress();
  log(chalk.yellow(`✅ RoleAccess deployed at proxy address: ${proxyAddress}`));
  await deployments.save('RoleAccess', {
    address: proxyAddress,
    abi: JSON.parse(RoleAccessFactory.interface.formatJson()),
  });
};

export default deployRoleAccess;
deployRoleAccess.tags = ['roleaccess'];
