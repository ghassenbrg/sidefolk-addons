import Foundation

/// How to write a flow, for a model: what `flow_guide` returns, what a description to the AI starts with. Models read English (D28).
enum Grammar {
    static let text = """
    A flow is JSON: {"trigger": …, "steps": […]}.

    trigger, one of:
      {"type":"manual"}
      {"type":"schedule","days":["mon","tue","wed","thu","fri"],"at":"08:30","catch_up":true}  (catch_up: run once when back if the Mac was off)
      {"type":"schedule","every_minutes":60}  (15 at least)
      {"type":"watch","kind":"url_change|site_status|file_changes|file_appears|folder_new_file|process_exits","target":"https://… or a full path or a program","contains":"words","pattern":"*.pdf","every_seconds":30,"rest_minutes":5}  (the last two only if asked for)
      {"type":"event","event":"reminder.fired|reminder.created|note.saved|calendar.starting|companion.finished|agent.finished|attention.changed|mac.woke","contains":"words"}  ({{trigger}} holds its words)

    each step does one thing and may have "id" (a-z 0-9 _, used to refer to its result), "name" (short plain words shown to the person) and "on_failure" ("stop", "carry_on", "retry"):
      {"id":"x","do":"<tool name>","with":{…the tool's values…}}
      {"id":"x","ai":"what to write","fields":{"total":"number","who":"text","ok":"yes_no","items":"list"}}  (fields only if a record is wanted: {{x.total}})
      {"id":"each","for_each":"{{list}}","limit":100,"item_failure":"stop|collect","steps":[…]}  ({{item}} {{index}} inside; afterwards {{each}} is the list of what each go made)
      {"choose":"{{value}}","paths":[{"when":"words","steps":[…]}],"else":[…]}
      {"try":[…],"recover":[…],"always":[…]}  ({{error}} in recover)
      {"id":"both","parallel":[{"name":"first","steps":[…]},{"name":"second","steps":[…]}]}  ({{both.first}}: 2 to 4 lanes)
      {"id":"r","call_flow":"its name","inputs":{"name":"{{value}}"}}  (waits for it; {{r}} is its result. Inside the flow: {{input.name}})
      {"finish":"{{value}}"}  (ends here with this result)
      {"id":"d","data":{"op":"parse_json|parse_csv|lines|join|field|filter|sort|unique|count|first|sum|number","from":"{{x}}","field":"a.b","test":"contains","than":"words","descending":true,"count":3,"separator":", "}}
      {"id":"f","form":{"title":"Check this","hours":72,"fields":[{"name":"ok","label":"Is it right?","kind":"text|number|yes_no|choice","options":["a","b"],"required":true}]}}  (waits on this page; {{f.ok}})
      {"id":"e","wait_for":{"event":"note.saved","contains":"words","minutes":60}}  (fails if it doesn't happen in time)
      {"id":"x","ai":"what the person's AI should write, with {{values}}"}  (no tools; it only writes text)
      {"id":"x","ask":"a question for the person","options":["Yes","No"]}
      {"id":"x","text":"words with {{values}}"}
      {"if":{"value":"{{x}}","test":"contains|not_contains|is|is_not|is_empty|not_empty|more_than|less_than","than":"rain"},"then":[…],"else":[…]}
      A field a record doesn't have counts as empty. A condition can't answer is_not or not_contains about it, or anything about a field of plain words: the step fails and says why, unless another check settles it.
      A yes_no value is true or false, and a condition or a choose reads it as yes or no. An empty list counts as empty. A path of a choose goes by a whole word, and one that is exactly the value comes first.
      {"wait_minutes":30}  (1 to 1440)
      {"run_flow":"another flow's name"}  (sets it off and carries on)
      {"id":"x","do":"companion.job","with":{"job":"a whole job in plain words"}}  (the companion does it with all its tools, under the person's trust settings)

    {{x}} is step x's result. Also {{trigger}} (what set it off), {{today}}, {{now}}.
    Use list_actions for the tools and their values. To tell the person, use the tool notify.user with title and body.

    Only some values may hold {{x}} and still run without asking: notes.save's text, reminders.create's title, notify.user's title and body, ask questions. Write everything else out in full: any other {{x}} works, but that step asks the person every time it runs.

    Nothing you write runs until the person allows it: flows are drafts until they answer a card that shows what it will do. A practice run reads for real and changes nothing.
    """
}
