# Picobrew::Api

Back in 2013, Picobrew launched a [Kickstarter](https://www.kickstarter.com/projects/1708005089/picobrew-zymatic-the-automatic-beer-brewing-applia/faqs#project_faq_69315) for the Zymatic, and advertised that they'd open source the firmware and provide web APIs.  I haven't seen any indication they plan on following through with that pledge despite many requests from their customers, so this project attempts to begin to fill that void.

The first version of this api provides some simple getters for various data from your Picobrew account - recipes, sessions, logs, notes, etc.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'picobrew-api', :github => 'toddq/picobrew-api'
```

And then execute:

    $ bundle

## Usage

```ruby
require 'picobrew/api'

picobrew = Picobrew::Api.new('your-username', 'your-password')
recipe = picobrew.get_all_recipes().first
control_program = picobrew.get_recipe_control_program(recipe['GUID'])
session = picobrew.get_sessions_for_recipe(recipe['GUID']).first
session_notes = picobrew.get_session_notes(session['id'])
session_log = picobrew.get_session_log(session['id'])
```

## Future

* Post notes to session
* Create/edit recipes
* Create/edit recipe control programs
* Document the api

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `gem build picobrew-api.gemspec` and `gem install ./picobrew-api-{version}.gem`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/toddq/picobrew-api.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
