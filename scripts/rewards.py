from typing import Dict, Optional, List, Union, Tuple

import itertools

import pydantic
import httpx

# VIT servicing station models


class Proposal(pydantic.BaseModel):
    internal_id: int
    proposal_id: str
    proposal_title: str
    proposal_funds: int
    proposal_url: str
    chain_proposal_id: str
    chain_proposal_index: int
    chain_vote_options: Dict[str, int]
    fund_id: int
    challenge_id: int
    challenge_type: str


# Jormungandr models

class Options(pydantic.BaseModel):
    start: int
    end: int


class TallyResult(pydantic.BaseModel):
    results: List[int]
    options: Options


class ProposalStatus(pydantic.BaseModel):
    index: int
    proposal_id: str
    options: Options
    tally: Optional[TallyResult]
    votes_cast: int


class VoteplanStatus(pydantic.BaseModel):
    id: str
    payload: str
    proposals: List[ProposalStatus]


async def get_proposals(vit_servicing_station_url: str) -> [Proposal]:
    async with httpx.AsyncClient() as client:
        proposals_result = await client.get(f"{vit_servicing_station_url}/api/v0/proposals")
        assert proposals_result.status_code == 200
        return [Proposal(**proposal_data) for proposal_data in proposals_result.json()]


async def get_active_voteplans(vit_servicing_station_url: str) -> [VoteplanStatus]:
    async with httpx.AsyncClient() as client:
        proposals_result = await client.get(f"{vit_servicing_station_url}/api/v0/vote/active/plans")
        assert proposals_result.status_code == 200
        return [VoteplanStatus(**proposal_data) for proposal_data in proposals_result.json()]


async def get_proposals_and_voteplans(vit_servicing_station_url: str) -> Tuple[Dict[str, Proposal], List[ProposalStatus]]:
    proposals_task = asyncio.create_task(get_proposals(vit_servicing_station_url))
    voteplans_task = asyncio.create_task(get_active_voteplans(vit_servicing_station_url))

    proposals = {proposal.proposal_id: proposal for proposal in await proposals_task}
    voteplans_proposals = list(itertools.chain.from_iterable(voteplan.proposals for voteplan in await voteplans_task))
    return proposals, voteplans_proposals


if __name__ == "__main__":
    import asyncio
    from pprint import pprint
    vit_station_url: str = "https://servicing-station.vit.iohk.io"
    proposals, voteplans = asyncio.run(get_proposals_and_voteplans(vit_station_url))
    pprint(proposals)
    pprint(voteplans)