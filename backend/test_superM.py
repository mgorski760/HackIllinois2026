from supermemory import Supermemory

client = Supermemory()

# Add a memory
client.add(
    content="User prefers dark mode",
    container_tags=["user-123"],
)

# Search memories
results = client.search.documents(
    q="dark mode",
    container_tags=["user-123"],
)