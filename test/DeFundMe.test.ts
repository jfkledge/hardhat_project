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
    await deFundMe.setPermissionManager(roleAccess.getAddress());
  });

  //判断设置的权限管理器是否正确
  it('should set roleAccess correctly', async () => {
    expect(await deFundMe.roleAccess()).to.equals(await roleAccess.getAddress());
  });

  //创建项目
  it('should create a project', async () => {
    const deadline = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now
    const tx = await deFundMe.createProject(
      'first defundme',
      'first defundme description',
      10,
      deadline,
      false
    );

    const detail = await deFundMe.getProjectDetail(0);
    expect(detail.creator).to.equal(admin.user);
    expect(detail.title).to.equal('first defundme');
    expect(detail.description).to.equal('first defundme description');
    expect(detail.goal).to.equal(10);
    expect(detail.deadline).to.equal(deadline);
    expect(detail.amountRaised).to.equal(0);
  });
  //测试创建项目时的权限
  it('should revert if non-admin tries to create a project', async () => {
    await expect(
      deFundMe
        .connect(user)
        .createProject(
          'second defundme',
          'second defundme description',
          20,
          Math.floor(Date.now() / 1000) + 3600,
          false
        )
    ).to.be.revertedWith(
      'AccessControl: account ' +
        user.address.toLowerCase() +
        ' is missing role ' +
        (await deFundMe.ADMIN_ROLE())
    );
  });
});
