import { time, loadFixture } from '@nomicfoundation/hardhat-toolbox/network-helpers';
import { anyValue } from '@nomicfoundation/hardhat-chai-matchers/withArgs';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { OrdersRelayer } from '../typechain-types';

describe('Orders Relayer', function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  let ordersRelayer: OrdersRelayer;
  async function deployFixture() {
    const OrdersRelayer = await ethers.getContractFactory('OrdersRelayer');
    const [deployer] = await ethers.getSigners();

    ordersRelayer = await OrdersRelayer.deploy('testcontract', 0);
    await ordersRelayer.deployed();
  }

  describe('generate order key', function () {
    it('should generate a unique length 32 key', async function () {
      await loadFixture(deployFixture);
      const tx = await ordersRelayer.generateOrderKey();
      console.log(tx);
      expect(tx).to.not.be.null;
    });
  });

  describe('create order', function () {
    it.only('should create order and emit event for creation', async function () {
      await loadFixture(deployFixture);
      const testOrderReq = {
        creator: '0x1576E5229Ea037215d4F58f1439EF27412E28c82',
        market: 'eth_swth',
        side: 'buy',
        quantity: 123123,
        orderType: 'limit',
        price: '123123',
        isReduceOnly: false,
      };

      const tx = await ordersRelayer.createOrder(
        testOrderReq.creator,
        testOrderReq.market,
        testOrderReq.side,
        testOrderReq.quantity,
        testOrderReq.orderType,
        testOrderReq.price,
        testOrderReq.isReduceOnly
      );
      let res = await tx.wait();
      console.log(res);
      expect(tx).to.not.be.null;
    });
  });
});
