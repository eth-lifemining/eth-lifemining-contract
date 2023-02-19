// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Vault.sol";

contract Challenge {

    /* Methods
    ** method: createChallenge
    ** method: startChallenge
    ** method: finishChallenge
    ** method: joinChallenge
    ** method: submitDailyCheckpoint
    ** method: claimForChallengeReward
    ** method: getChallengeDataIdsByHost
    ** method: getChallengeDataIdsByParticipant
    */

    enum ChallengeStatus {
        CREATED,
        STARTED,
        FINISHED
    }

    Vault private _vaultContract;

    // modifier onlyHost(challengeDataId ChallengeDataId) {
    modifier onlyHost(challengeCodeId string memory) {
        ChallengeDataId memory challengeDataId = ChallengeDataId(
            msg.sender,
            challengeCodeId
            ),
        require(
            msg.sender == challengeDataId.challengeHost,
            "Challenge: caller is not the challenge host"
            );
        _;
    }

    constructor(address vaultAddress) {
        _vaultContract = Vault(vaultAddress);
    }

    mapping(ChallengeDataId => ChallengeData) private _lifeminingChallenges;
    mapping(address => ChallengeDataId[]) private _participantChallenges; // participant to challengs
    mapping(address => ChallengeDataId[]) private _hostChallenges; // host to challenges
    mapping(ChallengeDataId => mapping(address => bool[]))
        private _challengeParticipantCheckpoints; // challenge to participant to checkpoints

    struct ChallengeDataId {
        address challengeHost;
        string challengeCodeId;
    }

    struct ChallengeData {
        uint256 challengeStatus;
        uint256 depositAmount;
        uint256 challengePeriodInDays;
        uint256 successThresholdIndays;
        uint256 startTime;
        uint256 endTime;
        address[] participants;
        address[] succeededParticipants;
        uint256 finalRewardForSuccessfulParticipants;
    }

    struct Participant {
        bool exists;
        uint256 lastCheckpointTimestamp;
        uint256 reward;
        bool claimed;
    }

    event ChallengeCreated(
        address indexed admin,
        uint256 startTimestamp,
        uint256 finishTimestamp
    );
    event ChallengeStarted(uint256 startTimestamp);
    event ChallengeFinished(uint256 finishTimestamp);
    event ParticipantJoined(address indexed participant);

    event DailyCheckpointSubmitted(
        address indexed participant,
        uint256 timestamp
    );

    event ChallengeRewardClaimed(
        address indexed participant,
        uint256 rewardAmount
    );

    function createChallenge(
        address host,
        string memory challengeCodeId,
        uint256 depositAmount,
        uint256 finalRewardForSuccessfulParticipants,
        uint256 challengePeriodInDays,
        uint256 successThresholdIndays,
        uint256 startTime,
        uint256 endTime
    ) external payable {
        require(
            msg.value == depositAmount,
            "Challenge: deposit amount must be same as msg.value"
        );

        require(
            challengePeriodInDays > 0,
            "Challenge: challenge duration must be greater than zero"
        );

        require(
            successThresholdIndays > 0,
            "Challenge: success threshold must be greater than zero"
        );

        require(
            successThresholdIndays <= challengePeriodInDays,
            "Challenge: success threshold must be less than or equal to challenge period"
        );

        require(
            startTime > block.timestamp,
            "Challenge: start time must be greater than current time"
        );

        require(
            endTime > startTime,
            "Challenge: end time must be greater than start time"
        );

        ChallengeDataId memory challengeDataId = ChallengeDataId(
            host,
            challengeCodeId
        );

        ChallengeData memory challengeData = ChallengeData(
            uint256(ChallengeStatus.CREATED),
            depositAmount,
            challengePeriodInDays,
            successThresholdIndays,
            startTime,
            endTime,
            new address[](0),
            new address[](0),
            finalRewardForSuccessfulParticipants
        );

        _lifeminingChallenges[challengeDataId] = challengeData;
        _hostChallenges[host].push(challengeDataId);

        emit ChallengeCreated(host, startTime, endTime);
    }

    function startChallenge(
        challengeCodeId
    ) external onlyHost(challengeCodeId) {

        ChallengeDataId memory challengeDataId = ChallengeDataId(
            msg.sender,
            challengeCodeId
        );

        require(
            _lifeminingChallenges[challengeDataId].challengeStatus ==
                uint256(ChallengeStatus.CREATED),
            "Challenge: challenge must be in created state"
        );

        _lifeminingChallenges[challengeDataId].challengeStatus = uint256(
            ChallengeStatus.STARTED
        );
        _lifeminingChallenges[challengeDataId].startTime = block.timestamp;

        emit ChallengeStarted(block.timestamp);
    }

    function finishChallenge(string memory challengeCodeId) external onlyHost(challengeCodeId) {
        ChallengeDataId memory challengeDataId = ChallengeDataId(
            msg.sender,
            challengeCodeId
        );

        require(
            _lifeminingChallenges[challengeDataId].challengeStatus ==
                uint256(ChallengeStatus.STARTED),
            "Challenge: challenge must be in started state"
        );

        _lifeminingChallenges[challengeDataId].challengeStatus = uint256(
            ChallengeStatus.FINISHED
        );
        _lifeminingChallenges[challengeDataId].endTime = block.timestamp;

        emit ChallengeFinished(block.timestamp);
    }

    function joinChallenge(
        string memory challengeCodeId,
        address host,
    ) external {
        ChallengeDataId memory challengeDataId = ChallengeDataId(
            host,
            challengeCodeId
        );

        require(
            _lifeminingChallenges[challengeDataId].challengeStatus ==
                uint256(ChallengeStatus.STARTED),
            "Challenge: challenge must be in started state"
        );

        require(
            _lifeminingChallenges[challengeDataId].startTime <= block.timestamp,
            "Challenge: challenge has not started yet"
        );

        require(
            _lifeminingChallenges[challengeDataId].endTime >= block.timestamp,
            "Challenge: challenge has already ended"
        );

        require(
            !_challengeParticipantCheckpoints[challengeDataId][msg.sender][0],
            "Challenge: participant already joined"
        );

        _lifeminingChallenges[challengeDataId].participants.push(msg.sender);
        _challengeParticipantCheckpoints[challengeDataId][msg.sender][0] = true;

        emit ParticipantJoined(msg.sender);
    }

    function submitDailyCheckpoint(
        string memory challengeCodeId,
        address host,
    ) external returns (bool) {
        ChallengeDataId memory challengeDataId = ChallengeDataId(
            host,
            challengeCodeId
        );

        require(
            _lifeminingChallenges[challengeDataId].challengeStatus ==
                uint256(ChallengeStatus.STARTED),
            "Challenge: challenge must be in started state"
        );

        require(
            _lifeminingChallenges[challengeDataId].startTime <= block.timestamp,
            "Challenge: challenge has not started yet"
        );

        require(
            _lifeminingChallenges[challengeDataId].endTime >= block.timestamp,
            "Challenge: challenge has already ended"
        );

        require(
            _challengeParticipantCheckpoints[challengeDataId][msg.sender][0],
            "Challenge: participant must join challenge first"
        );

        uint256 lastCheckpointTimestamp = _challengeParticipantCheckpoints[
            challengeDataId
        ][msg.sender][1];

        require(
            lastCheckpointTimestamp == 0 ||
                lastCheckpointTimestamp + 1 days <= block.timestamp,
            "Challenge: participant can submit checkpoint only once a day"
        );

        _challengeParticipantCheckpoints[challengeDataId][msg.sender][1] = block
            .timestamp;

        emit DailyCheckpointSubmitted(msg.sender, block.timestamp);

        return true;
    }

    function claimForChallengeReward(
        string memory challengeCodeId,
        address host,
    ) external returns (bool) {
        ChallengeDataId memory challengeDataId = ChallengeDataId(
            host,
            challengeCodeId
        );

        require(
            _lifeminingChallenges[challengeDataId].challengeStatus ==
                uint256(ChallengeStatus.FINISHED),
            "Challenge: challenge must be in finished state"
        );

        require(
            _lifeminingChallenges[challengeDataId].endTime <= block.timestamp,
            "Challenge: challenge has not ended yet"
        );

        require(
            _challengeParticipantCheckpoints[challengeDataId][msg.sender][0],
            "Challenge: participant must join challenge first"
        );

        require(
            !_challengeParticipantCheckpoints[challengeDataId][msg.sender][2],
            "Challenge: participant has already claimed reward"
        );

        uint256 lastCheckpointTimestamp = _challengeParticipantCheckpoints[
            challengeDataId
        ][msg.sender][1];

        require(
            lastCheckpointTimestamp + 1 days >= block.timestamp,
            "Challenge: participant has not submitted daily checkpoint"
        );

        uint256 rewardAmount = _lifeminingChallenges[challengeDataId]
            .finalRewardForSuccessfulParticipants /
            _lifeminingChallenges[challengeDataId].participants.length;

        _challengeParticipantCheckpoints[challengeDataId][msg.sender][2] = true;

        _vaultContract.withdrawFromVault(msg.sender, rewardAmount);

        emit ChallengeRewardClaimed(msg.sender, rewardAmount);

        return true;
    }

    function getChallengeDataIdsByHost(
        address host
    ) external view returns (ChallengeDataId[] memory) {
        return _challengeDataIdsByHost[host];
    }

    function getChallengeDataIdsByParticipant(
        address participant
    ) external view returns (ChallengeDataId[] memory) {
        return _challengeDataIdsByParticipant[participant];
    }

}
