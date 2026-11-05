import Foundation

/// How to write a flow, for a model: what `flow_guide` returns, what a description to the AI starts with. Models read English (D28).
enum Grammar {
    static let text = """
    A flow is JSON: {"trigger": …, "steps": […]}.

    "also_when":[…] adds more ways to start: schedules or events, up to 7, never a watch or manual. It starts once for each moment, however many match.
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
      {"id":"again","repeat":[…],"until":{"value":"{{check}}","test":"contains","than":"ready"},"times":10}  (does the steps, looks, goes round until it holds; failing at the limit. {{index}} is which go; afterwards {{again}} is what the last go made)
      {"choose":"{{value}}","paths":[{"when":"words","steps":[…]}],"else":[…]}
      {"try":[…],"recover":[…],"always":[…]}  ({{error}} in recover)
      {"id":"both","parallel":[{"name":"first","steps":[…]},{"name":"second","steps":[…]}]}  ({{both.first}}: 2 to 4 lanes)
      {"id":"r","call_flow":"its name","inputs":{"name":"{{value}}"}}  (waits for it; {{r}} is its result. Inside the flow: {{input.name}})
      {"finish":"{{value}}"}  (ends here with this result)
      {"id":"d","data":{"op":"parse_json|parse_csv|lines|join|field|filter|sort|unique|count|first|sum|number|batches|group|fallback","from":"{{x}}","field":"a.b","test":"contains","than":"words","descending":true,"count":3,"separator":", "}}
      {"id":"f","form":{"title":"Check this","hours":72,"fields":[{"name":"ok","label":"Is it right?","kind":"text|number|yes_no|choice","options":["a","b"],"required":true}]}}  (waits on this page; {{f.ok}})
      {"id":"e","wait_for":{"event":"note.saved","contains":"words","minutes":60}}  (fails if it doesn't happen in time)
      {"id":"x","ai":"what the person's AI should write, with {{values}}"}  (no tools; it only writes text)
      {"id":"x","ask":"a question for the person","options":["Yes","No"]}
      {"id":"x","text":"words with {{values}}"}
      {"if":{"value":"{{x}}","test":"contains|not_contains|is|is_not|is_empty|not_empty|more_than|less_than","than":"rain"},"then":[…],"else":[…]}
      {{step}} is what a tool said, everywhere: in a sentence, a for_each, a data step, to a called flow. A tool that gives fields has each as {{step.field}} (list_actions names them): for_each over {{step.items}}, not {{step}}, when the list is a field. What a loop, a repeat, a lane or a called flow gives from such a step is its words too: to keep a field past one, end it with a data step that holds it.
      A field a record doesn't have counts as empty. A condition can't answer is_not or not_contains about it, about a null, or about a step that gave nothing, or anything about a field of plain words: the step fails and says why, unless another check settles it.
      more_than, less_than, sum and the number op take a number a tool or a form gave as a number, or one written plainly: 12, -3, 12.5. Anything else, like 18 °C, $1,299.00, 12%, CPU: 12%, 1,5 or 1.500, stops the step and says why: take the number from a tool's field, or an AI step's field, instead.
      A yes_no value is true or false, and a condition or a choose reads it as yes or no; to a condition, false counts as empty. An empty list counts as empty, and is an answer: not_contains holds on it. A path of a choose goes by a whole word, and one that is exactly the value comes first: write the path as the word appears. Arabic joins "ال" to a word, so "الفاتورة" doesn't mention "فاتورة". A value that matches no path takes "else".
      {"wait_minutes":30}  (1 to 1440)
      {"run_flow":"another flow's name"}  (sets it off and carries on)
      {"id":"x","do":"companion.job","with":{"job":"a whole job in plain words"}}  (the companion does it with all its tools, under the person's trust settings)

    {{x}} is step x's result. Also {{trigger}} (what set it off), {{today}}, {{now}}.
    Use list_actions for the tools and their values. To tell the person, use the tool notify.user with title and body.

    Running or turning on asks once: the card says everything it does, and nothing asks again unless an edit adds something new. In Full access there's no card. What the host checks is where {{x}} goes. Words from outside run by themselves only in a field of plain words (text, message, body, title, subject, summary, note, comment, description, caption, reason, detail). A field that says where something goes (a url, address, channel, recipient, path, repository) or a choice asks each run unless you write the value out; a field that runs something (command, script, code, sql) refuses them, so write it out. A step's form says which applies.

    Nothing you write runs until the person allows it: flows are drafts until they answer a card that shows what it will do. A practice run reads for real and changes nothing.
    """
}
