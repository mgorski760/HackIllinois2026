from fastapi import FastAPI
from fastapi import Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from auth import GoogleUser, get_google_user

from calendar_routes import router as calendar_router
from agent_routes import router as agent_router

app = FastAPI(title="HackIllinois2026 API")

# Include routes
app.include_router(calendar_router)
app.include_router(agent_router)

# Allow requests from your iOS app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Temporary storage for the prompt
current_prompt: str = ""

class PromptRequest(BaseModel):
    prompt: str

@app.post("/prompt")
async def store_prompt(request: PromptRequest):
    global current_prompt
    current_prompt = request.prompt
    
    return {"status": "success", "received": current_prompt}

    

@app.get("/prompt")
async def get_prompt():
    return {"prompt": current_prompt}

@app.get("/debug/me")
async def who_am_i(user: GoogleUser = Depends(get_google_user)):
    return {"email": user.email}