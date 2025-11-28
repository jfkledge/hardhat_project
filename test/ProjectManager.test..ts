import { expect } from 'chai';
import { ethers, upgrades } from 'hardhat';
import { ProjectManager, RoleAccess } from '../typechain-types';

describe('ProjctManager', () => {
  let admin: any;
  let user: any;
  let projectManager: ProjectManager;
  let roleAccess: RoleAccess;

  beforeEach(async function () {
    [admin, user] = await ethers.getSigners();
    const RoleAccessFactory = await ethers.getContractFactory('RoleAccess');
    roleAccess = (await upgrades.deployProxy(RoleAccessFactory, [], {
      kind: 'uups',
      initializer: 'initialize',
    })) as RoleAccess;

    const ProjectManagerFactory = await ethers.getContractFactory('ProjectManager');
    projectManager = (await upgrades.deployProxy(ProjectManagerFactory, [], {
      kind: 'uups',
      initializer: 'initialize',
    })) as ProjectManager;
    //projectmanager register roleAccess
    await projectManager.registerModule(await roleAccess.getAddress());
    //roleAccess register projectmanager
    await roleAccess.registerModule(await projectManager.getAddress());
  });

  //创建项目
  it('should create a project', async () => {
    const deadline = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now
    const tx = await projectManager.createProject(
      'first defundme',
      'first defundme description',
      10,
      deadline,
      false
    );

    const detail = await projectManager.getProjectDetail(0);
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
      projectManager
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
        (await projectManager.ADMIN_ROLE())
    );
  });
});
