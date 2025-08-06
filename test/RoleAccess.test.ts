import { expect } from 'chai';
import { ethers, upgrades } from 'hardhat';
import { DeFundMe, RoleAccess } from '../typechain-types';

describe('DeFundMe', () => {
  let admin: any;
  let user: any;
  let deFundMe: DeFundMe;
  let roleAccess: RoleAccess;

  beforeEach(async function () {
    [admin, user] = await ethers.getSigners();
    const RoleAccessFactory = await ethers.getContractFactory('RoleAccess');
    roleAccess = (await upgrades.deployProxy(RoleAccessFactory, [], {
      kind: 'uups',
      initializer: 'initialize',
    })) as RoleAccess;

    const DeFundMeFactory = await ethers.getContractFactory('DeFundMe');
    deFundMe = (await upgrades.deployProxy(DeFundMeFactory, [], {
      kind: 'uups',
      initializer: 'initialize',
    })) as DeFundMe;

    //// 设置权限管理器
    await roleAccess.setDefundMe(deFundMe.getAddress());
  });
});
