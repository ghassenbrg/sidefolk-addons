import Foundation

/// How to write a flow, for a model: what `flow_guide` returns, what a description to the AI starts with. Models read English (D28).
enum Grammar {
    static let text = """
    A flow is JSON: {"trigger": …, "steps": […]}.

    trigger, one of:
      {"type":"manual"}
      {"type":"schedule","days":["mon","tue","wed","thu","fri"],"at":"08:30","catch_up":true}  (catch_up: run once when back if the Mac was off)
      {"type":"schedule","every_minutes":60}  (15 at least)
      {"type":"watch","kind":"url_change|site_status|file_changes|file_appears|folder_new_file|process_exits","target":"https://… or a full path or a program","contains":"words","pattern":"*.pdf"}

    each step does one thing and may have "id" (a-z 0-9 _, used to refer to its result), "name" (short plain words shown to the person) and "on_failure" ("stop", "carry_on", "retry"):
      {"id":"x","do":"<tool name>","with":{…the tool's values…}}
      {"id":"x","ai":"what the person's AI should write, with {{values}}"}  (no tools; it only writes text)
      {"id":"x","ask":"a question for the person","options":["Yes","No"]}
      {"id":"x","text":"words with {{values}}"}
      {"if":{"value":"{{x}}","test":"contains|not_contains|is|is_not|is_empty|not_empty|more_than|less_than","than":"rain"},"then":[…],"else":[…]}
      {"wait_minutes":30}  (1 to 1440)

    {{x}} is step x's result. Also {{trigger}} (what set it off), {{today}}, {{now}}.
    Use list_actions for the tools and their values. To tell the person, use the tool notify.user with title and body.

    Only some values may hold {{x}} and still run without asking: notes.save's text, reminders.create's title and notes, notify.user's title and body, ask questions. Write everything else out in full: any other {{x}} works, but that step asks the person every time it runs.

    Nothing you write runs until the person allows it: flows are drafts until they answer a card that shows what it will do. A practice run reads for real and changes nothing.
    """
}
