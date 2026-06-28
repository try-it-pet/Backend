from fastapi import APIRouter, HTTPException

from ..models import Pet, PetCreate
from ..store import PETS, next_pet_id

router = APIRouter(prefix="/pets", tags=["pets"])


@router.post("", response_model=Pet, status_code=201)
def create_pet(body: PetCreate) -> Pet:
    pet = Pet(id=next_pet_id(), **body.model_dump())
    PETS[pet.id] = pet
    return pet


@router.get("", response_model=list[Pet])
def list_pets() -> list[Pet]:
    return list(PETS.values())


@router.get("/{pet_id}", response_model=Pet)
def get_pet(pet_id: int) -> Pet:
    pet = PETS.get(pet_id)
    if pet is None:
        raise HTTPException(status_code=404, detail="pet not found")
    return pet
