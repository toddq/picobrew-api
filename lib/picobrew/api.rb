require 'json'
require 'httparty'
require 'nokogiri'

module Picobrew
end

class Picobrew::Api

    HOST = 'picobrew.com'
    include HTTParty
    base_uri 'https://picobrew.com'
    # debug_output

    attr_reader :cookies

    def initialize(username, password, cookies: nil, enableLogging: false)
        @username = username
        @password = password
        @enableLogging = enableLogging
        @http = Net::HTTP.new(HOST, 443)
        @http.use_ssl = true
        @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        @cached_sessions = []

        log "Created Picobrew object for #{username}"
        if !cookies.nil?
            log "Using provided cookies instead of logging in"
            @cookies = cookie_from_hash(cookies)
        else
            login()
        end
    end

    def login()
        log "Logging in"
        begin
            options = {
                :body => {'username' => @username, 'Password' => @password},
                :headers => {'Content-Type' => 'application/x-www-form-urlencoded; charset=UTF-8'},
                :follow_redirects => false
            }
            response = self.class.post('/account/loginAjax.cshtml', options)
            raise "No Set-Cookie in response" if response.get_fields('Set-Cookie').nil?
            @cookies = parse_cookie(response)
        rescue Exception => e
            raise "Authentication error: #{e}"
        end
        log "logged in"
    end

    def logged_in?()
        !@cookies.nil?
    end

    def get_all_recipes()
        log "Get All Recipes"
        begin
        	options = options({:body => {'option' => 'getAllRecipesForUser'}})
        	response = self.class.post('/JSONAPI/Zymatic/ZymaticRecipe.cshtml', options)
        	body = JSON.parse(response.body)
        rescue Exception => e
        	log "Error: #{e}"
        end
    end

    def get_recipe(recipe_id)
        log "Scrape Recipe #{recipe_id}"
        begin
            options = options({})
            response = self.class.get("/Members/Recipes/ParseRecipe.cshtml?id=#{recipe_id}", options)
            page = Nokogiri::HTML(response.body)
            recipe = {'specs' => {}}
            page.css('#user-specs-table tr').each do |element|
                recipe['specs'][element.css('td')[0].text] = element.css('td')[1].text
            end
            page.css('#editForm input').each do |element|
                if is_json? element['value']
                    recipe[element['name']] = JSON.parse(element['value'])
                else
                    recipe[element['name']] = element['value']
                end
            end
            recipe
        rescue Exception => e
            log "Error: #{e}"
        end
    end

    def get_recipe_control_program(recipe_id)
        log "Scrape Recipe Advanced Editor"
        begin
            options = options({})
            response = self.class.get("/members/recipes/editctlprogram?id=#{recipe_id}", options)
            page = Nokogiri::HTML(response.body)
            program = {'steps' => []}
            page.css('#stepTable tr').each do |row|
                next if row.at_css('input').nil?

                step = {
                    'index' => row.at_css('input')['data-index'].to_i,
                    'name' => row.at_css('input[name*=Name]')['value'],
                    'location' => row.at_css('select option[@selected=selected]').text,
                    'targetTemp' => row.at_css('input[name*=Temp]')['value'].to_i,
                    'time' => row.at_css('input[name*=Time]')['value'].to_i,
                    'drain' => row.at_css('input[name*=Drain]')['value'].to_i
                }

                program['steps'].push(step) if !step['name'].nil?
            end
            program
        rescue Exception => e
            log "Error: #{e}"
        end
    end

    def get_sessions_for_recipe(recipe_id)
        log "Get Sessions for Recipe #{recipe_id}"
        begin
            options = options({})
            response = self.class.get("/Members/Logs/brewingsessions.cshtml?id=#{recipe_id}", options)
            page = Nokogiri::HTML(response.body)
            sessions = []
            page.css('#BrewingSessions tbody tr').each do |row|
                sessions.push({
                    'name' => row.css('td.name').text,
                    'id' => row.css('td.name a')[0]['href'].gsub(/.*id=/, ''),
                    'date' => row.css('td.date').text,
                    'notes' => row.css('td')[3].text
                } )
            end
            sessions
        rescue Exception => e
            log "Error: #{e}"
        end
    end

    def get_all_sessions()
        log "Get All Sessions"
        begin
            options = options({:body => {'option' => 'getAllSessionsForUser'}})
            response = self.class.post('/JSONAPI/Zymatic/ZymaticSession.cshtml', options)
            body = JSON.parse(response.body)
        rescue Exception => e
            log "Error: #{e}"
        end
    end

    def get_session_log(session_id)
        log "Get Session Log for #{session_id}"
        # the sessions list contains references for guids, but the log api
        # wants a *different* id, so need to lookup one from the other
        if session_id.length > 6
            session_id = get_short_session_id_for_guid(session_id)
            raise Exception, "No short session id for guid" if session_id.nil?
            log "Get Session Log for #{session_id}"
        end
        begin
            options = options({:body => {'option' => 'getSessionLogs', 'sessionID' => session_id}})
            response = self.class.post('/JSONAPI/Zymatic/ZymaticSession.cshtml', options)
            body = JSON.parse(response.body)
        rescue Exception => e
            log "Error: #{e}"
        end
    end

    def get_session_notes(session_id)
        log "Get Session Notes for #{session_id}"
        if session_id.length > 6
            session_id = get_short_session_id_for_guid(session_id)
            raise Exception, "No short session id for guid" if session_id.nil?
            log "Get Session Notes for #{session_id}"
        end
        begin
            options = options({ :body => {'option' => 'getSessionNotes', 'sessionID' => session_id} })
            response = self.class.post('/JSONAPI/Zymatic/ZymaticSession.cshtml', options)
            body = JSON.parse(response.body)
        rescue Exception => e
            log "Error: #{e}"
        end
    end

    def get_recipe_id_for_session_id(session_guid)
        session = find_session(session_guid)
        return session['RecipeGUID'] if !session.nil?
    end

    def get_short_session_id_for_guid(session_guid)
        session = find_session(session_guid)
        return session['ID'] if !session.nil?
    end

    def find_session(session_guid)
        log "Looking up short session id for #{session_guid}"
        # quick and dirty cache expiration
        cache_sessions if @cached_sessions.empty? || @cached_at.to_i + 5 * 60 < Time.now.to_i
        return @cached_sessions.find {|session| session['GUID'] == session_guid}
    end

    def cache_sessions()
        log "Caching sesions"
        @cached_sessions = get_all_sessions()
        @cached_at = Time.now
    end

    def get_active_session()
        log "Get Active Session"
        begin
        	options = options({:body => {'option' => 'getZymaticsForUser', 'getActiveSession' => 'true'}})
        	response = self.class.post('/JSONAPI/Zymatic/ZymaticSession.cshtml', options)
            # TODO: return json?
            response.body
        rescue Exception => e
        	log "Error: #{e}"
        end
    end

    # don't really understand this one, not sure if id is required
    def check_active(session_id)
        log "Check if session is active: #{session_id}"
        begin
            options = options({:body => {'option' => 'checkActive', 'sessionId' => session_id}})
            response = self.class.post('/JSONAPI/Zymatic/ZymaticSession.cshtml', options)
            response.body
        rescue Exception => e
            log "Error: #{e}"
        end
    end

    # API used by Zymatic hardware
    # Does not require auth, but require user id and machine id
    # Move this to a separate class?
    def get_recipe_control_programs(user_id, machine_id)
        log "Get Recipe Control Programs"
        begin
            response = self.class.get("/API/SyncUser?user=#{user_id}&machine=#{machine_id}")
            response.body
        rescue Exception => e
            log "Error: #{e}"
        end
    end

    def is_json?(json)
        begin
            JSON.parse(json)
            return true
        rescue JSON::ParserError
            return false
        end
    end

    def options(params)
        { :headers => {
            'Content-Type' => 'application/x-www-form-urlencoded',
            'Cookie' => @cookies.to_cookie_string }
        }.merge params
    end

    def parse_cookie(resp)
        cookie_hash = CookieHash.new
        resp.get_fields('Set-Cookie').each { |c| cookie_hash.add_cookies(c) }
        cookie_hash
    end

    def cookie_from_hash(hsh)
        cookie_hash = CookieHash.new
        cookie_hash.add_cookies(hsh)
        cookie_hash
    end

    def log(msg)
    	puts msg if @enableLogging
    end
end
