# Planwise

## Inspiration
Technological development within the industry has accelerated substantially in recent years, and the velocity of work has never been faster. Yet despite this progress, bottlenecks have become a greater pain point for professionals and everyday people alike - from carving out time for workflow optimizations to building systems that align with their personal work preferences. It's time for progress to abstract away the busy work of planning your day the way you want it. That's where Planwise comes in. We empower your workflow, giving you more time to focus on what actually matters.

## What It Does
Planwise is an iOS app designed to help you quickly build out your calendar based on your personal preferences. Simply prompt with your voice, text, or an image, and see the immediate impact. Planwise handles the heavy lifting while understanding the context of your current calendar events and workflow preferences. Never again will you waste hours on things that don't drive your creativity and passion.

## How We Built It
We built Planwise using the following technologies:
- **Swift/SwiftUI** for a dynamic and native frontend experience, ensuring minimal interference to the user's workflow.
- **Modal Container with openai/gpt-oss-20b** to power the conversion of prompts into executable calendar instructions.
- **FastAPI** to bridge the Modal Container and calendar modification orders.
- **SuperMemory** to store and leverage user preferences as personalized context.
- **Railway** for seamless and rapid deployment performance.

## Challenges We Ran Into
One of the biggest challenges we faced was getting our AI model to reliably follow the correct instructions within the user's calendar. The model initially lacked sufficient context about past and future events, which led to some significant edge cases. Our team's background is primarily in cybersecurity and Swift development, so we were thrown into the deep end when it came to making an AI model work for us. We also ran into issues with Google OAuth in Swift, which cost us a considerable amount of time that could have been spent building out more features.

## Accomplishments That We're Proud Of
We're really proud of the UI and UX we built for Planwise. We wanted the app's aesthetics to feel light and modern, and our team spent significant time thinking through how users would interact with it — because Planwise is meant to enhance your workflow, not get in the way. We're also proud of what we achieved with our AI model. Despite having no prior experience deploying LLMs on Modal or with prompt engineering in general, we were genuinely excited to see a language model successfully generating structured orders for our backend to execute. Finally, we're proud of our context management system, which ensures our Modal container has sufficient context from the user's Google Calendar and personal preferences.

## What We Learned
The idea that resonated most with our team was pushing the limits of what we thought we could do. As mentioned, none of us had experience building LLM-based systems — but we didn't let that stop us. We tried, failed, tried again, failed even more spectacularly, and eventually made it work.

## What's Next for Planwise
Looking ahead, we plan to add integrations with tools like Slack and Notion to further automate and better understand our users' workflows and work styles. We also want to fine-tune our models to minimize errors and reduce our LLM costs.
