// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/FactoryV1.sol";
import "../src/FactoryV2.sol";
import "../src/InscribedERC20V2.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract FactoryTest is Test {
    Factory_V1 factoryV1;
    FactoryV2 factoryV2;
    InscribedERC20V2 implementation;
    TransparentUpgradeableProxy proxy;
    ProxyAdmin proxyAdmin;
    address owner;

    function setUp() public {
        owner = address(this);

        factoryV1 = new Factory_V1();
        implementation = new InscribedERC20V2();
        proxyAdmin = new ProxyAdmin(owner);
        proxy = new TransparentUpgradeableProxy(address(factoryV1), address(proxyAdmin), new bytes(0));
        factoryV2 = FactoryV2(address(proxy));
    }

    function testDeployAndMintV1() public {
        address tokenAddr = factoryV1.deployInscription("TOKEN", 1000 * 10 ** 18, 10 * 10 ** 18);
        assertEq(InscribedERC20(tokenAddr).name(), "TOKEN");

        // 使用 prank 模拟正确的调用者
        vm.prank(owner);
        factoryV1.mintInscription(tokenAddr);
        assertEq(InscribedERC20(tokenAddr).balanceOf(owner), 10 * 10 ** 18);
    }

    function testUpgradeAndMintV2() public {
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(address(proxy)), address(factoryV2), bytes(""));

        address tokenAddr = factoryV2.deployInscription("TOKEN", 1000 * 10 ** 18, 10 * 10 ** 18, 0.01 ether);
        assertEq(InscribedERC20V2(tokenAddr).name(), "TOKEN");

        vm.deal(address(this), 1 ether);
        factoryV2.mintInscription{value: 0.01 ether}(tokenAddr);
        assertEq(InscribedERC20V2(tokenAddr).balanceOf(owner), 10 * 10 ** 18);
    }
}
