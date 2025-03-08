// PRS.sol
// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./TimeUnit.sol";
import "./CommitReveal.sol";

contract RPS {
    uint public numPlayer = 0;
    uint public reward = 0;
    uint public numInput = 0;
    
    mapping(address => uint) public player_choice;
    mapping(address => bool) public player_not_played;
    address[] public players;
    
    CommitReveal public commitReveal;
    TimeUnit public timeunit;

    constructor() {
        commitReveal = new CommitReveal();
        timeunit = new TimeUnit();
    }

    function addPlayer() public payable {
        require(
            msg.sender == 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4 ||
            msg.sender == 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2 ||
            msg.sender == 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db ||
            msg.sender == 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB,
            "Not an allowed player"
        );
        require(numPlayer < 2, "Game is full");
        require(msg.value == 1 ether, "Must send 1 ether to join");
        
        if (numPlayer == 0) {
            timeunit.setStartTime();
        } else {
            require(msg.sender != players[0], "Same player cannot join twice");
        }
        
        reward += msg.value;
        player_not_played[msg.sender] = true;
        players.push(msg.sender);
        numPlayer++;
    }

    modifier isPlayers() {
        require(msg.sender == players[0] || msg.sender == players[1], "Not a valid player");
        _;
    }

    function commitMove(bytes32 _commitment, uint256 _choice, string memory _salt) external isPlayers {
        commitReveal.commitMove(msg.sender, _commitment, _choice, _salt);
    }

    function input(uint256 choice) external isPlayers {
        require(player_not_played[msg.sender], "Already revealed");
        require(choice >= 0 && choice <= 4, "Invalid Choice");
        require(commitReveal.reveal(msg.sender), "Invalid reveal");
        
        player_choice[msg.sender] = choice;
        player_not_played[msg.sender] = false;
        numInput++;

        if (numInput == 2) {
            _checkWinnerAndPay();
        }
    }

    function getHash(uint256 choice, string memory salt) public view returns (bytes32) {
        return commitReveal.getHash(choice, salt);
    }

    function forceGame() public payable {
        require(numPlayer == 2, "Not enough players");
        require(player_not_played[msg.sender] == false, "Player has already played");
        require(timeunit.elapsedSeconds() > 600, "Time limit not exceeded");
        
        payable(players[0]).transfer(reward / 2);
        payable(players[1]).transfer(reward / 2);
        resetGame();
    }

    function Callback() public payable {
        require(numPlayer == 1, "Invalid state");
        require(timeunit.elapsedSeconds() > 300, "Time limit not exceeded");
        
        payable(players[0]).transfer(reward);
        resetGame();
    }

    function _checkWinnerAndPay() private {
        uint256 p0Choice = player_choice[players[0]];
        uint256 p1Choice = player_choice[players[1]];
        address payable account0 = payable(players[0]);
        address payable account1 = payable(players[1]);

        if ((p0Choice + 1) % 5 == p1Choice || (p0Choice + 3) % 5 == p1Choice) {
            account1.transfer(reward);
        } else if ((p1Choice + 1) % 5 == p0Choice || (p1Choice + 3) % 5 == p0Choice) {
            account0.transfer(reward);
        } else {
            account0.transfer(reward / 2);
            account1.transfer(reward / 2);
        }
        resetGame();
    }

    function resetGame() internal {
        delete player_choice[players[0]];
        delete player_choice[players[1]];
        numPlayer = 0;
        reward = 0;
        numInput = 0;
        commitReveal.resetCommit(players[0], players[1]);
        delete players;
    }
}
