// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.9;

contract ScrumVoting { // ορισμός της κλάσης ScrumVoting

    struct Voter{
        uint voterId;
        address addr;
        uint remainingTokens;
    }

    struct Proposal{
        uint propId;
        uint[] propVoters;
        uint count;
    }

    mapping(address => Voter) voterDetails; // χαρτογράφηση των ψηφοφόρων με τα στοιχεία τους
    Voter [] voters;
    Proposal [] public proposals;
    // Πίνακας που θα αποθηκεύει τα id των νικητήριων προτάσεων σε περίπτωση ισοβαθμίας.
    uint[] public winnerProposals;
    uint public winningProposalId; // id της νικήτριας πρότασης
    address[] public winners; // πίνακας νικητών - όσων ψήφισαν την νικήτρια πρόταση
    address public scrumMaster; // ο διαχειριστής του project και ιδιοκτήτης του smart contract
    uint votersCount = 0; // πλήθος των εγγεγραμένων έως τώρα ψηφοφόρων
    enum Stage {Init, Reg, Vote, Done}
    Stage public stage;
    uint256 public currentVoteNumber; // Κρατάμε τον αριθμό της τρέχουσας ψηφοφορίας

    event Winner(uint256 proposalId, uint256 vote); // Συμβάν που εκπέμπεται κάθε φορά που υπάρχει νικητής

    constructor(uint numProposals, uint numVoters) { //constructor
        // Αρχικοποίηση του διαχειριστή με τη διεύθυνση του κατόχου του έξυπνου συμβολαίου
        scrumMaster = msg.sender;
        uint[] memory emptyArray;
        // Εισαγωγή προτάσεων και σύνδεση αυτων με τα id της λίστας των προτάσεων.
        // Οι προτάσεις αριθμούνται από το 1 για να ειναι φανερό 
        for (uint i = 1; i < numProposals+1; i++) {
            proposals.push(Proposal({
                propId: i,
                propVoters: emptyArray,
                count: 0
            }));
        }
        // Εισαγωγή ψηφοφόρων.
        for (uint256 i = 0; i < numVoters; i++) {
            voters.push(Voter({
                voterId: i,
                addr: address(0),
                remainingTokens: 0
            }));
        }
        stage = Stage.Reg;
        // Αρχικοποίηση του αριθμού ψηφοφορίας.
        currentVoteNumber = 1;
        // Αρχικοποίηση του id της νικητήριας πρότασης.
        winningProposalId = 0;
    }

    // Δημιουργία modifier που επιτρέπει την κλήση μιας συνάρτησης μόνο από τον Scrum Master.
    modifier onlyMaster() {
        require(msg.sender == scrumMaster, "Not Scrum Master.");
        _;
    }
    
    // Ελέγχει αν υπάρχει νικήτηρια πρόταση και αν υπάρχει έστω και μια ψήφο σε κάποια πρόταση.
    modifier votingInProgress() {
        require(winningProposalId == 0, "Voting has already ended");
        bool voted = false;
        for (uint i = 0; i < proposals.length; i++) {
            if (proposals[i].propVoters.length > 0) {
                voted = true;
                break;
            }
        }
        require(voted, "At least one proposal must be voted");
        _;
    }

    modifier onlyUnregistered() {
        require(voterDetails[msg.sender].addr == address(0), "Already registered.");
        _;
    }

    modifier onlyNotScrumMaster() {
        require(msg.sender != scrumMaster, "Scrum Master cannot register.");
        _;
    }

    modifier hasEnoughEther(uint256 amount) {
        require(msg.value >= amount, "Insufficient Ether sent.");
        _;
    }

    modifier stageIsReg() {
        require(uint(stage) == uint(Stage.Reg), "Not in register stage.");
        _;
    }

    function register() public payable stageIsReg onlyUnregistered onlyNotScrumMaster hasEnoughEther(0.005 ether){ // εγγραφή ψηφοφόρου
        voters[votersCount].voterId = votersCount;
        // Αρχικοποίηση του ψηφοφόρου
        voters[votersCount].addr = msg.sender;
        voters[votersCount].remainingTokens = 5; // ο ψηφοφόρος έχει 5 dots
        voterDetails[msg.sender] = voters[votersCount];
        votersCount++;
    }

    modifier mustToVote(uint _propId, uint _count) {
        require(uint(stage) == uint(Stage.Vote), "Not in Vote stage.");
        require(_propId < proposals.length+1, "Invalid proposal ID");
        require(voterDetails[msg.sender].remainingTokens >= _count, "Insufficient dots");
        _;
    }

    function vote(uint _propId, uint _count) public mustToVote(_propId, _count){ // ψηφίζει την πρόταση _propId με _count dots
        /*
        Δύο έλεγχοι:
        το μέλος που καλεί έχει επαρκές πλήθος dots;
        η πρόταση υπάρχει;
        Για τους δύο ελέγχους χρησιμοποιείται ο modifier mustToVote.
        */
        
        // Ενημέρωση της κάλπης της πρότασης _propId με εισαγωγή των _count ψήφων που της δίνει το μέλος
        for (uint i = 0; i < proposals.length; i++) {
            if(proposals[i].propId == _propId){
                proposals[i].propVoters.push(voterDetails[msg.sender].voterId);
                proposals[i].count += _count;
            }
        }
        // Ενημέρωση του υπολοίπου dots του μέλους
        voterDetails[msg.sender].remainingTokens -= _count;
    }

    modifier stageIsDone() {
        require(uint(stage) == uint(Stage.Done), "Not in Done stage.");
        _;
    }
    function revealWinners() public onlyMaster stageIsDone votingInProgress{ // θα υλοποιήσετε modifier με το όνομα onlyMaster
    // Ταξινόμησε τις προτάσεις με φθίνουσα σειρά ψήφων
        for (uint i = 0; i < proposals.length - 1; i++) {
            for (uint j = 0; j < proposals.length - i - 1; j++) {
                if (proposals[j].count < proposals[j + 1].count) {
                    Proposal memory temp = proposals[j];
                    proposals[j] = proposals[j + 1];
                    proposals[j + 1] = temp;
                }
            }
        }

        uint maxVotes = proposals[0].count;

        for (uint i = 0; i < proposals.length && proposals[i].count == maxVotes; i++) {
            winnerProposals.push(proposals[i].propId);
        }

        // If there are multiple proposals with the maximum votes, choose one randomly
        if (winnerProposals.length > 1) {
            // Αν υπάρχει ισοπαλία στην πρώτη θέση, κάλεσε την συνάρτηση drawWinner
            // Η drawWinner θα επιλέγει τυχαία (με παραγωγή ψευδοτυχαίου αριθμού)
            // την νικήτρια πρόταση ανάμεσα στις ισοψηφίες (2 ή περισσότερες)
            // και θα ενημερώνει την winningProposalId με το id της νικήτριας πρότασης
            winningProposalId = drawWinner();
        } else {
            winningProposalId = winnerProposals[0];
        }
        // Ενημέρωση του πίνακα winners με τις διευθύνσεις όσων ψήφισαν τη νικήτρια πρόταση
        for (uint256 i = 0; i < proposals[winningProposalId].propVoters.length; i++) {
            winners.push(voters[proposals[winningProposalId].propVoters[i]].addr);
        }
        // Εκπέμπουμε το συμβάν Winner
        emit Winner(winningProposalId, currentVoteNumber);
    
    }

    function drawWinner() internal returns (uint){
        // Επιλογή νικητή βάση timestamp.
        uint winnerIndex = block.timestamp % winnerProposals.length;
        winningProposalId = winnerProposals[winnerIndex];
        
        return winningProposalId;
    }

    function withdraw() public payable onlyMaster {
        payable(msg.sender).transfer(address(this).balance);
    }

    function reset(uint numProposals) public onlyMaster {
        delete proposals;
        
        uint[] memory emptyArray;
        // Εισαγωγή προτάσεων και σύνδεση αυτων με τα id της λίστας των προτάσεων.
        // Οι προτάσεις αριθμούνται από το 1 για να ειναι φανερό 
        for (uint i = 1; i < numProposals+1; i++) {
            proposals.push(Proposal({
                propId: i,
                propVoters: emptyArray,
                count: 0
            }));
        }
        uint numVoters = voters.length;
        delete voters;
        for (uint256 i = 0; i < numVoters; i++) {
            voters.push(Voter({
                voterId: i,
                addr: address(0),
                remainingTokens: 0
            }));
        }
        stage = Stage.Reg;

        // Αυξάνουμε τον αριθμό της ψηφοφορίας
        currentVoteNumber++;
        // Επαναρχικοποίηση του id της νικητήριας πρότασης.
        winningProposalId = 0;
        // Διαγραφή των winners.
        delete winners;
    }

    function advanceState() public onlyMaster {
        require(uint(stage) < uint(Stage.Done), "Already in the final stage.");
        stage = Stage(uint(stage) + 1);
    }
}