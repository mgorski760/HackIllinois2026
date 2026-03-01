# Planwise 📱

## Inspiration
Technological development within the industry has accelerated substantially in recent years, and the velocity of work has never been faster. Yet despite all this progress, bottlenecks have somehow gotten worse - professionals and everyday people alike are still stuck carving out time for workflow optimizations and building systems just to keep up with their own preferences. Enough is enough. It's time for technology to actually do the boring stuff for you. That's where Planwise comes in. We take care of your schedule so you can get back to doing the things that actually excite you.

## What It Does
Planwise is an iOS app that helps you build out your calendar exactly the way you want it, without the headache. Just tell it what you need through voice, text, or an image, and watch it get to work. Planwise handles the heavy lifting while keeping tabs on your existing events and workflow preferences. No more burning hours on scheduling tasks that have nothing to do with your creativity or passion.

## How We Built It
We built Planwise using the following technologies:
- **Swift/SwiftUI** for a dynamic and native frontend experience, ensuring minimal interference to the user's workflow.
- **Modal Container with openai/gpt-oss-20b** to power the conversion of prompts into executable calendar instructions.
- **FastAPI** to bridge the Modal Container and calendar modification orders.
- **Railway** for seamless and rapid deployment performance for our backend.

## Challenges We Ran Into
Getting our agent to reliably follow the right instructions inside a user's calendar was trickier than we expected. Early on, the agent lacked sufficient context about past and future events, leading to some truly chaotic edge cases. On top of that, our team's background is mostly in cybersecurity and Swift development, so building an LLM-powered agent was a genuine leap into the unknown. We also got humbled by Google OAuth in Swift and with our agent, which ate up way more of our time than we'd like to admit.

## Accomplishments That We're Proud Of
We're really proud of the UI and UX we put together for Planwise. We wanted it to feel light, modern, and out of the way, because the whole point is to make your life easier, not add another thing to manage. We're also pretty stoked about what we pulled off with our agent. None of us had ever deployed an agent on Modal or done serious prompt engineering before, so watching it successfully generate structured instructions for our backend was a genuinely exciting moment. And finally, we're proud of our context management system, which keeps our agent well-informed with the right data from your Google Calendar and personal preferences.

## What We Learned
The biggest takeaway for our team was simple: just try. None of us had experience building agent-based systems, but we committed anyway. We tried, failed, tried again, failed even more spectacularly, and eventually cracked it. Turns out the deep end isn't so bad once you're already in it.

## What's Next for Planwise
Looking ahead, we want to integrate with tools like Slack and Notion to further automate workflows and get a clearer picture of how our users like to work. We also want to fine-tune our models to reduce errors and keep our LLM costs in check. One thing we really wished we had more time for was building out the personal preferences layer within SuperMemory. We wanted to go deeper on capturing each user's workflow habits and feeding that into our agent as richer, more precise context - and that's very much on the roadmap.
