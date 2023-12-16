// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

contract CryptoPe {
    string public name = "CryptoPe";
    // manager : execute txs
    mapping(address => uint256) public managers;
    address public ownerAddress;
    address public usdtAddress;

    // upi mappings
    mapping(address => string) public addressToUpi; // userAddress => upiStringAddress
    mapping(string => address) public upiToAddress; // upiStringAddress => userAddress

    mapping(address => uint256) public poolTokenBalances; // balance of all tolens
    mapping(address => mapping(address => uint256)) public userTokenBalance;

    uint256 public fees;
    uint256 public feesPercent = 5; // fees = 0.005%
    uint256 public constant swapPoolFees = 3000; // 0.3%

    struct Order {
        uint256 orderId;
        address userAddress;
        address tokenAddress;
        uint256 depositAmount;
        uint256 remainingAmount;
        uint256 fiatOrderAmount;
        uint256 tokenAccumulated;
        uint256 grids;
        uint256 executedGrids;
        bool open;
    }

    // orders
    uint256 public ordersCount = 0;
    mapping(uint256 => Order) public orders;

    // positions
    // total position in the contract
    uint256 public positionCount = 0;
    // userAddress => positionId
    mapping(address => uint256) public userPosition; // each user will have only 1 postion

    // position Id => order ids
    mapping(uint256 => uint256[]) public positionToOrders;

    // events
    event Invested(
        uint256 indexed orderId,
        address indexed userAddress,
        address indexed tokenAddress,
        uint256 amount,
        uint256 grid
    );

    event OrderCancelled(
        uint256 indexed orderId,
        uint256 executedGrids,
        uint256 remainingAmount
    );

    event Withdraw(
        address indexed user,
        uint256[] orderIds,
        address tokenAddress,
        uint256 fiatAmount,
        uint256 tokenAmount
    );

    constructor() {
        managers[msg.sender] = 1;
        ownerAddress = msg.sender;
    }

    //* modifiers
    modifier onlyManager() {
        require(managers[msg.sender] == 1);
        _;
    }

    modifier onlyOwner() {
        require(
            ownerAddress == msg.sender,
            "only owner can perform this operation"
        );
        _;
    }

    //* functions
    // FUNCTION : to setInputToken
    function setInputToken(address _token) public onlyManager {
        usdtAddress = _token;
    }

    function addManager(address _address) public onlyOwner {
        managers[_address] = 1;
    }

    function updateFeePercent(uint256 _newFeePercent) public onlyOwner {
        require(_newFeePercent > 0, "Invalid new percentage!");
        feesPercent = _newFeePercent;
    }

    function updateUpi(string memory _upiAddress) public {
        bytes memory strByte = bytes(_upiAddress);
        require(strByte.length != 0, "Invalid UPI address");
        addressToUpi[msg.sender] = _upiAddress;
        upiToAddress[_upiAddress] = msg.sender;
    }

    function startStrategy(
        address _tokenAddress,
        uint256 _singleOrderAmount,
        uint256 _noOfOrders
    ) public {
        require(_singleOrderAmount > 0, "Order amount less than min limit!");
        uint256 token_order_amount = _singleOrderAmount * _noOfOrders;

        // transfer the specified amount of USDT to this manager wallet
        // TransferHelper.safeTransferFrom(
        //     usdtAddress, // tokenAddress
        //     msg.sender, // userAddresss - transferFrom
        //     ownerAddress, // transferTo
        //     token_order_amount // amount
        // );

        // start new position
        uint256 positionId = ++positionCount;

        // start new order
        ordersCount++;
        Order memory new_order = Order({
            orderId: ordersCount,
            userAddress: msg.sender,
            tokenAddress: _tokenAddress,
            fiatOrderAmount: _singleOrderAmount,
            depositAmount: token_order_amount,
            remainingAmount: 0,
            tokenAccumulated: 0,
            executedGrids: 0,
            grids: 0,
            open: true
        });

        orders[ordersCount] = new_order;

        // position
        // add order to current position array
        positionToOrders[positionId].push(ordersCount);
        userPosition[msg.sender] = positionId;

        // updating the pool usdt address
        poolTokenBalances[usdtAddress] += token_order_amount;
        userTokenBalance[msg.sender][usdtAddress] += token_order_amount;
        // emit Invested(ordersCount, msg.sender, token_order_amount, _noOfOrders, _tokenAddress);
        emit Invested(
            ordersCount,
            msg.sender,
            _tokenAddress,
            token_order_amount,
            0
        );
    }

    function getUserDepositBalance(
        address _userAddress,
        address _tokenAddress
    ) public view returns (uint256) {
        return userTokenBalance[_userAddress][_tokenAddress];
    }

    function getUserOrders(
        address _userAddress
    ) public view returns (Order[] memory) {
        uint256 _userPosition = userPosition[_userAddress];
        uint256[] memory _positionOrderIds = positionToOrders[_userPosition];

        uint256 count = _positionOrderIds.length;
        Order[] memory filteredOrders = new Order[](count);

        uint256 index = 0;
        for (uint256 i = 0; i < count; i++) {
            filteredOrders[index] = orders[_positionOrderIds[i]];
            index++;
        }
        return filteredOrders;
    }

    function getPendingOrders() public view returns (Order[] memory) {
        uint256 count = 0;
        for (uint256 i = 1; i <= ordersCount; i++) {
            if (orders[i].open) {
                count++;
            }
        }

        Order[] memory filteredOrder = new Order[](count);
        uint256 index = 0;

        for (uint256 i = 1; i <= ordersCount; i++) {
            if (orders[i].open) {
                filteredOrder[index] = orders[i];
                index++;
            }
        }
        return filteredOrder;
    }

    function updateOrderStatus(uint256[] memory _orderIds) public {
        for (uint256 i = 0; i < _orderIds.length; i++) {
            require(_orderIds[i] > 0, "Order id must be greater than 0");
            Order storage selected_order = orders[_orderIds[i]];

            require(selected_order.open, "Order already closed!");
            selected_order.executedGrids += 1;

            if (selected_order.executedGrids == selected_order.grids) {
                selected_order.open = false;
            }
        }
    }
}
