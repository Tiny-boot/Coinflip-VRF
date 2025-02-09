// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {DirectFundingConsumer} from "./DirectFundingConsumer.sol";

interface LinkTokenInterface {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract Coinflip is Ownable {
    // A map of the player and their corresponding requestId
    mapping(address => uint256) public playerRequestID;
    // A map that stores the player's 3 Coinflip guesses
    mapping(address => uint8[3]) public bets;
    // An instance of the random number requestor, client interface
    DirectFundingConsumer private vrfRequestor;

    event BetPlaced(address indexed player, uint8[3] guesses);
    event BetResult(address indexed player, bool won);

    constructor() Ownable(msg.sender) {
        vrfRequestor = new DirectFundingConsumer();
    }

    function fundOracle() external returns (bool) {
        address linkAddr = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
        uint256 amount = 5 * 10 ** 18; // 5 LINK tokens

        // Ensure the contract has enough LINK tokens
        LinkTokenInterface linkToken = LinkTokenInterface(linkAddr);
        require(linkToken.transfer(address(vrfRequestor), amount), "Funding failed");
        return true;
    }

    function userInput(uint8[3] calldata Guesses) external {
        for (uint256 i = 0; i < 3; i++) {
            require(Guesses[i] == 0 || Guesses[i] == 1, "Guesses must be 0 or 1");
        }
        bets[msg.sender] = Guesses;
        uint256 requestId = vrfRequestor.requestRandomWords(false);
        playerRequestID[msg.sender] = requestId;
        emit BetPlaced(msg.sender, Guesses);
    }

    function checkStatus() external view returns (bool) {
        uint256 requestId = playerRequestID[msg.sender];
        require(requestId != 0, "No request found");

        (, bool fulfilled,) = vrfRequestor.getRequestStatus(requestId);
        return fulfilled;
    }

    function determineFlip() external view returns (bool) {
        uint256 requestId = playerRequestID[msg.sender];
        require(requestId != 0, "No request found");

        (, bool fulfilled, uint256[] memory randomWords) = vrfRequestor.getRequestStatus(requestId);
        require(fulfilled, "Request not fulfilled");
        require(randomWords.length >= 3, "Insufficient random words");


        uint8[3] memory flips;
        for (uint256 i = 0; i < 3; i++) {
            flips[i] = uint8(randomWords[i] % 2);
        }
        
        uint8[3] memory guesses = bets[msg.sender];

        return (flips[0] == guesses[0] && flips[1] == guesses[1] && flips[2] == guesses[2]);
    }
}