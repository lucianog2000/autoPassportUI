// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
contract AutoPassport is ChainlinkClient, ConfirmedOwner, ERC721, ERC721Burnable, ERC721URIStorage  {
    using Chainlink for Chainlink.Request;
    bytes32 private jobId;
    uint256 private fee;
    string public vinProcessing = "";
    string [] public vinCreated;
    struct Car {
        string brand;
        string model;
        string vin;
        string color_code;
        string date_of_manufacture;
        string warranty_expiration_date;
        string fuel_type;
        uint mileage;
        string[] repair_history;
        string[] maintenance_history;
        string last_update;
        bool hasFines;
    }
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;
    mapping (uint256 => Car) private _cars;
    mapping (string => uint256) private _vinToTokenId;
    mapping (string => bool) private _isVinUsed;
    mapping (uint256 => bool) private _isTokenIdUsed;
    constructor() ERC721("Autopassport", "Pass") ConfirmedOwner(msg.sender){
        setChainlinkToken(0x326C977E6efc84E512bB9C30f76E30c160eD06FB);
        setChainlinkOracle(0x40193c8518BB267228Fc409a613bDbD8eC5a97b3);
        jobId = "7d80a6386ef543a3abb52817f6707e3b";
        fee = (1 * LINK_DIVISIBILITY) / 10; // 0,1 * 10**18 (Varies by network and job)
    }
    function createAutoPassport(
        address to, 
        string memory brand, 
        string memory model, 
        string memory vin, 
        string memory color_code, 
        string memory date_of_manufacture, 
        string memory warranty_expiration_date, 
        string memory fuel_type, 
        string memory last_update, 
        string memory uriIpfsUrl) public {
        require(_isVinUsed[vin] == false, "Car with this VIN already exists");
        uint256 tokenId = _tokenIdCounter.current() + 1;
        require(_isTokenIdUsed[tokenId] == false, "Car with this tokenId already exists");
        _cars[tokenId] = Car(
            brand, 
            model, 
            vin, 
            color_code, 
            date_of_manufacture, 
            warranty_expiration_date, 
            fuel_type, 
            0, 
            new string[](0), 
            new string[](0),
            last_update,
            false);
        _vinToTokenId[vin] = tokenId;
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uriIpfsUrl);
        _isVinUsed[vin] = true;
        vinCreated.push(vin);
        _isTokenIdUsed[tokenId] = true;
    }
    function updateAutoPassport(
        string memory vin,
        uint mileage,
        string memory newRepair,
        string memory newMaintenance,
        string memory newURI,
        string memory last_update
    ) public {
        require(_isVinUsed[vin] == true, "Car with this VIN does not exist");
        uint256 tokenId = _vinToTokenId[vin];
        Car storage carObject = _cars[tokenId];
        require(
            carObject.mileage < mileage,
            "New mileage value must be greater than the current value"
        );
        carObject.mileage = mileage;
        if (bytes(newRepair).length > 0 && keccak256(bytes(newRepair)) != keccak256(bytes("undefined"))) {
            carObject.repair_history.push(newRepair);
        }
        if (bytes(newMaintenance).length > 0 && keccak256(bytes(newMaintenance)) != keccak256(bytes("undefined"))) {
            carObject.maintenance_history.push(newMaintenance);
        }
        _setTokenURI(tokenId, newURI);
        carObject.last_update = last_update;
    }
    function requestFinesApi(string memory vin) public {
        Chainlink.Request memory req = buildChainlinkRequest(
            jobId,
            address(this),
            this.fulfillMultipleParameters.selector
        );
        vinProcessing = vin;
        string memory apiUrl = string(abi.encodePacked("https://fines-api.onrender.com/cars/fines/", vin));
        req.add("get", apiUrl);
        req.add("path", "hasFines");
        sendChainlinkRequest(req, fee);
    }
    function fulfillMultipleParameters(
        bytes32 requestId,
        string memory hasFinesResponse
    ) public recordChainlinkFulfillment(requestId) {
        uint256 tokenId = _vinToTokenId[vinProcessing];
        Car storage carObject = _cars[tokenId];
        for (; keccak256(bytes(vinProcessing)) != keccak256(bytes("")); ) {
            if (keccak256(bytes(hasFinesResponse)) == keccak256(bytes("true"))) {
                carObject.hasFines = true;
                vinProcessing = "";
            }
            if (keccak256(bytes(hasFinesResponse)) == keccak256(bytes("false"))) {
                carObject.hasFines = false;
                vinProcessing = "";
            }
        }
    }
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }
    function checkFines(string memory vin) public {
        require(_isVinUsed[vin] == true, "Car with this VIN does not exist");
        requestFinesApi(vin);
    }
    function checkFinesAndReturnCar(string memory vin) public returns (Car memory objCar) {
        require(_isVinUsed[vin] == true, "Car with this VIN does not exist");
        requestFinesApi(vin);
        uint256 tokenId = _vinToTokenId[vin];
        Car storage carObject = _cars[tokenId];
        objCar = Car(
            carObject.brand, 
            carObject.model, 
            carObject.vin,
            carObject.color_code, 
            carObject.date_of_manufacture,
            carObject.warranty_expiration_date,
            carObject.fuel_type,
            carObject.mileage,
            carObject.repair_history,
            carObject.maintenance_history,
            carObject.last_update,
            carObject.hasFines);
    }
    function getObjCarByVIN(
        string memory vin
    )
        public
        view
        returns (
            uint256 tokenId,
            Car memory objCar,
            string memory uri
        )
    {
        require(_isVinUsed[vin] == true, "Car with this VIN does not exist");
        tokenId = _vinToTokenId[vin];
        Car storage carObject = _cars[tokenId];
        objCar = Car(
            carObject.brand, 
            carObject.model, 
            carObject.vin,
            carObject.color_code, 
            carObject.date_of_manufacture,
            carObject.warranty_expiration_date,
            carObject.fuel_type,
            carObject.mileage,
            carObject.repair_history,
            carObject.maintenance_history,
            carObject.last_update,
            carObject.hasFines);
        uri = super.tokenURI(tokenId);
    }
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
    function supportsInterface(bytes4 interfaceId) public view virtual override (ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}