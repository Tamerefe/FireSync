require 'csv'
require 'json'
require 'yaml'
require 'optparse'
require 'securerandom'

# ANSI Color Codes
class Colors
  RED = "\033[31m"
  GREEN = "\033[32m"
  YELLOW = "\033[33m"
  BLUE = "\033[34m"
  MAGENTA = "\033[35m"
  CYAN = "\033[36m"
  WHITE = "\033[37m"
  BOLD = "\033[1m"
  RESET = "\033[0m"
end

# Default Configuration Constants
DEFAULT_CONFIG = {
  'weights' => { 'damage' => 1.0, 'firerate' => 1.0, 'magazine' => 1.0, 'range' => 1.0, 'denominator' => 1.0 },
  'game' => { 'rounds' => 5, 'starting_balance' => 900, 'round_bonuses' => [1700, 2000, 2600, 3500] },
  'economy' => { 'sell_rate' => 0.7, 'win_bonus' => 500, 'loss_bonus' => 200 },
  'events' => {
    'foggy_weather' => { 'probability' => 0.15, 'effect' => 'range', 'modifier' => -0.2 },
    'armored_enemies' => { 'probability' => 0.12, 'effect' => 'damage', 'modifier' => -0.15 },
    'windy_conditions' => { 'probability' => 0.10, 'effect' => 'recoil', 'modifier' => 0.1 }
  },
  'perks' => {
    'economist' => { 'name' => 'Economist', 'effect' => 'price', 'modifier' => -0.1 },
    'control_master' => { 'name' => 'Control Master', 'effect' => 'recoil', 'modifier' => -0.15 },
    'long_shot' => { 'name' => 'Long Shot', 'effect' => 'range', 'modifier' => 0.1 }
  },
  'attachments' => {
    'extended_mag' => { 'name' => 'Extended Magazine', 'effect' => 'magazine', 'modifier' => 10, 'price' => 300 },
    'grip' => { 'name' => 'Grip', 'effect' => 'recoil', 'modifier' => -0.1, 'price' => 200 },
    'suppressor' => { 'name' => 'Suppressor', 'effects' => { 'damage' => -0.05, 'recoil' => -0.1 }, 'price' => 400 }
  },
  'difficulty' => {
    'easy' => { 'weights' => { 'low' => 0.6, 'medium' => 0.3, 'high' => 0.1 } },
    'normal' => { 'weights' => { 'low' => 0.33, 'medium' => 0.34, 'high' => 0.33 } },
    'hard' => { 'weights' => { 'low' => 0.1, 'medium' => 0.3, 'high' => 0.6 } }
  }
}

# Weapon struct for storing weapon data
Weapon = Struct.new(:name, :price, :damage, :firerate, :magazine, :falloff, :range, :recoil, :balanced_score, :dps)

# Language cache
$language_cache = {}

def create_default_profile
  {
    'total_games' => 0,
    'wins' => 0,
    'losses' => 0,
    'draws' => 0,
    'weapon_usage' => {},
    'weapon_wins' => {},
    'weapon_elo' => {},
    'achievements' => []
  }
end

def load_profile
  profile_file = 'profile.json'
  if File.exist?(profile_file)
    begin
      JSON.parse(File.read(profile_file))
    rescue => e
      puts colorize(t('errors.profile_error', message: e.message), Colors::RED)
      create_default_profile
    end
  else
    create_default_profile
  end
end

def load_settings
  settings_file = 'settings.json'
  if File.exist?(settings_file)
    begin
      JSON.parse(File.read(settings_file))
    rescue => e
      puts colorize("Error loading settings: #{e.message}", Colors::RED)
      create_default_settings
    end
  else
    create_default_settings
  end
end

def create_default_settings
  {
    'language' => 'en',
    'difficulty' => 'normal',
    'events_enabled' => true,
    'colored_output' => true,
    'profile_reset' => false
  }
end

def save_settings(settings)
  begin
    File.write('settings.json', JSON.pretty_generate(settings))
  rescue => e
    puts colorize("Error saving settings: #{e.message}", Colors::RED)
  end
end

def log_event(message)
  timestamp = Time.now.strftime("%Y-%m-%d %H:%M:%S")
  log_entry = "[#{timestamp}] #{message}"
  
  begin
    File.open('run.log', 'a') do |file|
      file.puts(log_entry)
    end
  rescue => e
    puts colorize("Error writing to log: #{e.message}", Colors::RED)
  end
end

def colorize(text, color_code)
  return text if $game_state.no_color
  "#{color_code}#{text}#{Colors::RESET}"
end

def validate_csv_headers(csv_path)
  required_headers = ['name', 'price', 'damage', 'firerate', 'magazine', 'falloff', 'range', 'recoil']
  
  begin
    CSV.foreach(csv_path, headers: true) do |row|
      headers = row.headers
      missing_headers = required_headers - headers
      
      if missing_headers.any?
        puts colorize("Error: Missing required CSV headers: #{missing_headers.join(', ')}", Colors::RED)
        puts colorize("Required headers: #{required_headers.join(', ')}", Colors::RED)
        return false
      end
      
      # Only check first row for headers
      break
    end
    return true
  rescue => e
    puts colorize("Error reading CSV file: #{e.message}", Colors::RED)
    return false
  end
end

# Game state
class GameState
  attr_accessor :weapons, :config, :language, :difficulty, :profile, :current_perk, :current_attachments, :settings, :inventory, :seed, :auto_mode, :no_color
  
  def initialize
    @weapons = []
    @config = {}
    @language = 'en'
    @difficulty = 'normal'
    @profile = create_default_profile
    @current_perk = nil
    @current_attachments = []
    @settings = load_settings
    @inventory = []
    @seed = nil
    @auto_mode = false
    @no_color = false
  end
end

# Global game state
$game_state = GameState.new

def load_config
  config_file = 'config.yml'
  if File.exist?(config_file)
    begin
      $game_state.config = YAML.load_file(config_file)
    rescue => e
      puts colorize("Error loading config: #{e.message}", Colors::RED)
      $game_state.config = DEFAULT_CONFIG
    end
  else
    puts colorize("Config file not found, using defaults", Colors::YELLOW)
    $game_state.config = DEFAULT_CONFIG
  end
end

def load_language(lang)
  # Check cache first
  return $language_cache[lang] if $language_cache[lang]
  
  lang_file = "lang/#{lang}.yml"
  if File.exist?(lang_file)
    begin
      $language_cache[lang] = YAML.load_file(lang_file)
    rescue => e
      puts colorize("Error loading language file: #{e.message}", Colors::RED)
      $language_cache[lang] = load_language('en') # Fallback to English
    end
  else
    puts colorize("Language file not found, using English", Colors::YELLOW)
    $language_cache[lang] = load_language('en')
  end
end

def t(key, params = {})
  lang_data = load_language($game_state.language)
  keys = key.split('.')
  value = lang_data.dig(*keys)
  
  if value.nil?
    return key
  end
  
  # Replace parameters
  params.each do |k, v|
    value = value.gsub("%{#{k}}", v.to_s)
  end
  
  value
end

def load_weapons(csv_path)
  weapons = []
  
  begin
    CSV.foreach(csv_path, headers: true) do |row|
      begin
        # Parse weapon data
        name = row['name']
        price = row['price'].to_i
        damage = row['damage'].to_i
        firerate = row['firerate'].to_f
        magazine = row['magazine'].to_i
        falloff = row['falloff'].to_i
        range = row['range'].to_f
        recoil = row['recoil'].to_f
        
        # Validate data
        if name.nil? || name.empty? || price <= 0 || damage <= 0 || 
           firerate <= 0 || magazine <= 0 || falloff < 0 || range <= 0 || recoil < 0
          puts colorize("Warning: Skipping invalid weapon data: #{name}", Colors::YELLOW)
          next
        end
        
        # Create weapon and compute scores
        weapon = Weapon.new(name, price, damage, firerate, magazine, falloff, range, recoil)
        compute_balanced_score(weapon)
        compute_dps(weapon)
        weapons << weapon
        
      rescue => e
        puts colorize("Warning: Error parsing weapon data: #{e.message}", Colors::YELLOW)
        next
      end
    end
  rescue => e
    puts colorize(t('errors.csv_error', message: e.message), Colors::RED)
    return []
  end
  
  weapons
end

def compute_balanced_score(weapon)
  weights = $game_state.config['weights']
  
  # Apply weights to the formula
  numerator = (weapon.damage * weights['damage'] * weapon.firerate * weights['firerate']) + 
              (weapon.magazine * weights['magazine'] * weapon.range * weights['range'])
  denominator = (weapon.falloff + weapon.recoil) * weights['denominator']
  
  # Prevent division by zero
  if denominator == 0
    weapon.balanced_score = 0.0
  else
    weapon.balanced_score = numerator.to_f / denominator
  end
end

def compute_dps(weapon)
  # DPS = (damage * firerate) / 60 (convert RPM to per second)
  weapon.dps = (weapon.damage * weapon.firerate) / 60.0
end

def apply_perk_effects(weapon)
  return weapon unless $game_state.current_perk
  
  perk = $game_state.config['perks'][$game_state.current_perk]
  return weapon unless perk
  
  case perk['effect']
  when 'price'
    weapon.price = (weapon.price * (1 + perk['modifier'])).to_i
  when 'recoil'
    weapon.recoil *= (1 + perk['modifier'])
  when 'range'
    weapon.range *= (1 + perk['modifier'])
  end
  
  # Recompute scores after perk application
  compute_balanced_score(weapon)
  compute_dps(weapon)
  weapon
end

def apply_attachment_effects(weapon)
  $game_state.inventory.each do |attachment_key|
    attachment = $game_state.config['attachments'][attachment_key]
    next unless attachment
    
    if attachment['effects']
      # Multiple effects (like suppressor)
      attachment['effects'].each do |effect, modifier|
        case effect
        when 'damage'
          weapon.damage = (weapon.damage * (1 + modifier)).to_i
        when 'recoil'
          weapon.recoil *= (1 + modifier)
        end
      end
    else
      # Single effect
      case attachment['effect']
      when 'magazine'
        weapon.magazine += attachment['modifier']
      when 'recoil'
        weapon.recoil *= (1 + attachment['modifier'])
      end
    end
  end
  
  # Recompute scores after attachment application
  compute_balanced_score(weapon)
  compute_dps(weapon)
  weapon
end

def apply_random_event(weapon)
  return weapon unless $game_state.settings['events_enabled']
  
  events = $game_state.config['events']
  
  # Select only one event per round
  selected_event = nil
  events.each do |event_key, event_data|
    if rand < event_data['probability']
      selected_event = { key: event_key, data: event_data }
      break
    end
  end
  
  if selected_event
    event_key = selected_event[:key]
    event_data = selected_event[:data]
    
    puts colorize(t("events.#{event_key}"), Colors::CYAN)
    log_event("Round event: #{event_key} applied")
    
    case event_data['effect']
    when 'damage'
      weapon.damage = (weapon.damage * (1 + event_data['modifier'])).to_i
    when 'range'
      weapon.range *= (1 + event_data['modifier'])
    when 'recoil'
      weapon.recoil *= (1 + event_data['modifier'])
    end
    
    # Recompute scores after event application
    compute_balanced_score(weapon)
    compute_dps(weapon)
  end
  
  weapon
end

def print_about(weapons, page = 0)
  weapons_per_page = 15
  total_pages = (weapons.size / weapons_per_page.to_f).ceil
  
  puts "\n#{colorize(t('weapons.database_title'), Colors::BOLD + Colors::BLUE)}"
  puts "=" * 140
  
  # Print header
  printf("%-20s %-12s %-8s %-15s %-15s %-15s %-15s %-10s %-15s %-10s\n",
         t('weapons.headers.name'), t('weapons.headers.price'), t('weapons.headers.damage'),
         t('weapons.headers.firerate'), t('weapons.headers.magazine'), t('weapons.headers.falloff'),
         t('weapons.headers.range'), t('weapons.headers.recoil'), t('weapons.headers.balanced_score'),
         t('weapons.headers.dps'))
  puts "-" * 140
  
  # Print weapons for current page
  start_index = page * weapons_per_page
  end_index = [start_index + weapons_per_page - 1, weapons.size - 1].min
  
  weapons[start_index..end_index].each do |weapon|
    printf("%-20s $%-11d %-8d %-15.2f %-15d %-15d %-15.2f %-10.1f %-15.2f %-10.2f\n",
           weapon.name, weapon.price, weapon.damage, weapon.firerate, weapon.magazine,
           weapon.falloff, weapon.range, weapon.recoil, weapon.balanced_score, weapon.dps)
  end
  
  puts "=" * 140
  puts "#{t('weapons.total_weapons', count: weapons.size)} | Page #{page + 1}/#{total_pages}"
  
  if total_pages > 1
    puts "\n#{colorize('Navigation: ', Colors::CYAN)}"
    puts "n - Next page | p - Previous page | q - Quit"
    
    loop do
      print "> "
      input = gets.chomp.downcase
      
      case input
      when 'n'
        if page < total_pages - 1
          print_about(weapons, page + 1)
        else
          puts colorize("Already on last page", Colors::YELLOW)
        end
        break
      when 'p'
        if page > 0
          print_about(weapons, page - 1)
        else
          puts colorize("Already on first page", Colors::YELLOW)
        end
        break
      when 'q'
        break
      else
        puts colorize("Invalid input", Colors::YELLOW)
      end
    end
  end
  
  puts
end

def get_safe_input(prompt, valid_range = nil)
  loop do
    print prompt
    input = gets.chomp.strip
    
    # Check if input is empty or non-numeric
    if input.empty? || !input.match?(/^\d+$/)
      puts colorize(t('errors.invalid_number'), Colors::RED)
      next
    end
    
    choice = input.to_i
    
    # Check if choice is within valid range
    if valid_range && !valid_range.include?(choice)
      puts colorize(t('errors.invalid_range', min: valid_range.begin, max: valid_range.end), Colors::RED)
      next
    end
    
    return choice
  end
end

def select_perk
  puts "\n#{colorize(t('perks.title'), Colors::BOLD + Colors::MAGENTA)}"
  puts "=" * 50
  puts "1. #{t('perks.economist')}"
  puts "2. #{t('perks.control_master')}"
  puts "3. #{t('perks.long_shot')}"
  
  choice = get_safe_input(t('perks.choose_perk'), 1..3)
  
  perks = ['economist', 'control_master', 'long_shot']
  $game_state.current_perk = perks[choice - 1]
  
  puts colorize("Selected perk: #{$game_state.config['perks'][$game_state.current_perk]['name']}", Colors::GREEN)
end

def attachment_shop(balance)
  puts "\n#{colorize(t('attachments.title'), Colors::BOLD + Colors::MAGENTA)}"
  puts "=" * 50
  puts "#{t('game.balance', amount: balance)}"
  puts
  
  total_cost = 0
  loop do
    puts "1. #{t('attachments.extended_mag')}"
    puts "2. #{t('attachments.grip')}"
    puts "3. #{t('attachments.suppressor')}"
    puts "0. #{t('attachments.finish')}"
    
    choice = get_safe_input(t('attachments.buy_attachment'), 0..3)
    break if choice == 0
    
    attachments = ['extended_mag', 'grip', 'suppressor']
    attachment_key = attachments[choice - 1]
    attachment = $game_state.config['attachments'][attachment_key]
    
    if attachment['price'] <= balance
      $game_state.inventory << attachment_key
      total_cost += attachment['price']
      balance -= attachment['price']
      puts colorize(t('attachments.attachment_bought', name: attachment['name']), Colors::GREEN)
      log_event("Attachment purchased: #{attachment['name']}")
    else
      puts colorize(t('attachments.insufficient_balance'), Colors::RED)
    end
  end
  
  total_cost
end



def display_weapons_for_round(weapons, group_range, balance, round_type = nil)
  # Get round type display name from language file
  if round_type && round_type != 'mixed'
    round_title = t("round.weapon_types.#{round_type}")
  else
    round_title = t('round.available_weapons')
  end
  
  puts "\n#{colorize(round_title, Colors::BOLD + Colors::BLUE)}"
  puts "=" * 60
  puts "#{t('game.balance', amount: balance)}"
  puts
  
  # Get weapons from the range (for backward compatibility)
  available_weapons = weapons.is_a?(Array) ? weapons : weapons[group_range]
  
  if available_weapons.empty?
    puts colorize(t('round.no_weapons'), Colors::RED)
    return []
  end
  
  # Display weapons with numbers and DPS
  available_weapons.each_with_index do |weapon, index|
    number = index + 1
    affordable = weapon.price <= balance ? colorize(t('weapons.affordable'), Colors::GREEN) : colorize(t('weapons.not_affordable'), Colors::RED)
    printf("%2d. %-15s - $%-6d (DPS: %.1f) (%s)\n", number, weapon.name, weapon.price, weapon.dps, affordable)
  end
  
  available_weapons
end

def computer_select_weapon(available_weapons)
  # Sort weapons by balanced score
  sorted_weapons = available_weapons.sort_by(&:balanced_score)
  
  # Handle case when there are less than 3 weapons
  if sorted_weapons.size < 3
    # For 1-2 weapons, just return random selection
    return sorted_weapons.sample
  end
  
  # Divide into three tiers
  tier_size = [sorted_weapons.size / 3, 1].max
  low_tier = sorted_weapons[0...tier_size]
  high_tier = sorted_weapons[-tier_size..-1]
  medium_tier = sorted_weapons[tier_size...-tier_size]
  
  # Get difficulty weights
  difficulty_config = $game_state.config['difficulty'][$game_state.difficulty]
  weights = difficulty_config['weights']
  
  # Choose tier based on weights
  rand_val = rand
  if rand_val < weights['low']
    tier = low_tier
  elsif rand_val < weights['low'] + weights['medium']
    tier = medium_tier
  else
    tier = high_tier
  end
  
  # If tier is empty, fallback to random selection
  tier = available_weapons if tier.empty?
  
  tier.sample
end

def categorize_weapon(weapon)
  # Define weapon categories based on CS2 weapon types
  case weapon.name
  when /AK47|M4A4|M4A1-S|AUG|FAMAS|Galil AR|SG 553/
    'rifles'
  when /AWP|G3SG1|SCAR-20|SSG 08/
    'snipers'
  when /Desert Eagle|Glock-18|USP-S|P250|CZ75 Auto|Tec-9|Five-SeveN|Dual Berettas|R8 Revolver/
    'pistols'
  when /Mag-7|Nova|Sawed-Off|XM1014/
    'shotguns'
  when /PP-Bizon|MAC-10|MP7|MP5-SD|MP9|P90|UMP-45/
    'smgs'
  when /M249|Negev/
    'lmgs'
  else
    # Debug: Log uncategorized weapons
    puts colorize("Warning: Uncategorized weapon: #{weapon.name}", Colors::YELLOW)
    'other'
  end
end

def play_round(weapons, round_number, balance)
  puts "\n#{colorize(t('round.title', number: round_number), Colors::BOLD + Colors::CYAN)}"
  puts "=" * 50
  
  # Determine weapon category and price range for this round
  # Round 1: Pistols (Budget) - Starting with $900
  # Round 2: SMGs (Mid-tier) - After first round bonus
  # Round 3: Shotguns (Close combat) - After second round bonus
  # Round 4: Rifles (Main weapons) - After third round bonus
  # Round 5: Snipers & LMGs (Elite) - After fourth round bonus
  
  case round_number
  when 1
    # Round 1: Pistols (Budget weapons)
    available_weapons = weapons.select { |w| categorize_weapon(w) == 'pistols' && w.price <= 800 }
    round_type = 'pistols'
  when 2
    # Round 2: SMGs (Mid-tier weapons)
    available_weapons = weapons.select { |w| categorize_weapon(w) == 'smgs' && w.price <= 2000 }
    round_type = 'smgs'
  when 3
    # Round 3: Shotguns (Close combat)
    available_weapons = weapons.select { |w| categorize_weapon(w) == 'shotguns' && w.price <= 2500 }
    round_type = 'shotguns'
  when 4
    # Round 4: Rifles (Main weapons)
    available_weapons = weapons.select { |w| categorize_weapon(w) == 'rifles' && w.price <= 4000 }
    round_type = 'rifles'
  when 5
    # Round 5: Snipers & LMGs (Elite weapons)
    available_weapons = weapons.select { |w| ['snipers', 'lmgs'].include?(categorize_weapon(w)) && w.price <= 6000 }
    round_type = 'elite'
  else
    # Fallback for any additional rounds - mixed weapons
    available_weapons = weapons.select { |w| w.price <= balance }
    round_type = 'mixed'
  end
  
  # If no weapons in category/price range, fallback to affordable weapons
  if available_weapons.empty?
    available_weapons = weapons.select { |w| w.price <= balance }
    round_type = 'mixed'
  end
  
  # Debug: Show category info
  puts colorize("DEBUG: Round #{round_number} - Category: #{round_type} - Weapons: #{available_weapons.size}", Colors::CYAN)
  
  # Display available weapons
  available_weapons = display_weapons_for_round(available_weapons, nil, balance, round_type)
  
  if available_weapons.empty?
    puts colorize(t('round.no_weapons'), Colors::RED)
    return balance, nil, nil
  end
  
  # Player selection
  player_weapon = nil
  loop do
    if $game_state.auto_mode
      choice = rand(1..available_weapons.size)
      selected_weapon = available_weapons[choice - 1]
      puts colorize(t('round.auto_selection', weapon: selected_weapon.name), Colors::YELLOW)
    else
      choice = get_safe_input(t('round.choose_weapon', count: available_weapons.size), 1..available_weapons.size)
      selected_weapon = available_weapons[choice - 1]
    end
    
    if selected_weapon.price > balance
      puts colorize(t('round.insufficient_balance', needed: selected_weapon.price, have: balance), Colors::RED)
      next
    end
    
    player_weapon = selected_weapon.dup
    balance -= selected_weapon.price
    break
  end
  
  # Apply perk and attachment effects
  player_weapon = apply_perk_effects(player_weapon)
  player_weapon = apply_attachment_effects(player_weapon)
  
  # Computer selection - must choose from the same category
  computer_weapon = computer_select_weapon(available_weapons).dup
  puts colorize("DEBUG: Computer selected #{computer_weapon.name} (Category: #{categorize_weapon(computer_weapon)})", Colors::MAGENTA)
  
  # Apply the same random event to both weapons
  round_event = select_round_event
  if round_event
    player_weapon = apply_event_to_weapon(player_weapon, round_event)
    computer_weapon = apply_event_to_weapon(computer_weapon, round_event)
  end
  
  puts "\n#{colorize(t('round.you_selected', weapon: player_weapon.name, score: '%.2f' % player_weapon.balanced_score), Colors::GREEN)}"
  puts colorize(t('round.computer_selected', weapon: computer_weapon.name, score: '%.2f' % computer_weapon.balanced_score), Colors::RED)
  
  # Determine winner
  puts "\n" + "-" * 40
  if player_weapon.balanced_score > computer_weapon.balanced_score
    puts colorize(t('round.you_win'), Colors::GREEN + Colors::BOLD)
    result = :win
    bonus = $game_state.config['economy']['win_bonus']
  elsif player_weapon.balanced_score < computer_weapon.balanced_score
    puts colorize(t('round.computer_wins'), Colors::RED + Colors::BOLD)
    result = :loss
    bonus = $game_state.config['economy']['loss_bonus']
  else
    puts colorize(t('round.draw'), Colors::YELLOW + Colors::BOLD)
    result = :draw
    bonus = 0
  end
  puts "-" * 40
  
  # Add bonus money
  balance += bonus
  puts colorize("Bonus: +$#{bonus}", Colors::CYAN) if bonus > 0
  
  # Round summary
  puts colorize(t('round.summary', player_score: '%.2f' % player_weapon.balanced_score, computer_score: '%.2f' % computer_weapon.balanced_score, result: result.to_s.upcase), Colors::BOLD)
  
  # Ask if player wants to sell weapon
  sell_price = (player_weapon.price * $game_state.config['economy']['sell_rate']).to_i
  print "#{t('economy.sell_weapon', amount: sell_price)}"
  sell_choice = gets.chomp.downcase
  
  if sell_choice == 'y' || sell_choice == 'e'
    balance += sell_price
    puts colorize(t('economy.weapon_sold', amount: sell_price), Colors::GREEN)
  else
    puts colorize(t('economy.weapon_not_sold'), Colors::YELLOW)
  end
  
  # Log round results
  log_event("Round #{round_number}: Player #{player_weapon.name} (#{player_weapon.balanced_score.round(2)}) vs Computer #{computer_weapon.name} (#{computer_weapon.balanced_score.round(2)}) - #{result.upcase}")
  
  sleep(1) unless $game_state.auto_mode
  
  return balance, result, player_weapon
end

def select_round_event
  return nil unless $game_state.settings['events_enabled']
  
  events = $game_state.config['events']
  selected_event = nil
  
  events.each do |event_key, event_data|
    if rand < event_data['probability']
      selected_event = { key: event_key, data: event_data }
      break
    end
  end
  
  selected_event
end

def apply_event_to_weapon(weapon, event)
  event_key = event[:key]
  event_data = event[:data]
  
  puts colorize(t("events.#{event_key}"), Colors::CYAN)
  
  case event_data['effect']
  when 'damage'
    weapon.damage = (weapon.damage * (1 + event_data['modifier'])).to_i
  when 'range'
    weapon.range *= (1 + event_data['modifier'])
  when 'recoil'
    weapon.recoil *= (1 + event_data['modifier'])
  end
  
  # Recompute scores after event application
  compute_balanced_score(weapon)
  compute_dps(weapon)
  weapon
end

def play_game(weapons)
  if weapons.empty?
    puts colorize(t('errors.no_weapons'), Colors::RED)
    return
  end
  
  puts "\n#{colorize(t('game.title'), Colors::BOLD + Colors::BLUE)}"
  puts "=" * 50
  puts "#{t('game.welcome')}"
  puts "#{t('game.rounds_info', rounds: $game_state.config['game']['rounds'])}"
  puts "#{t('game.budget_info')}"
  puts "#{t('game.score_info')}"
  puts "#{t('game.difficulty', level: $game_state.difficulty.capitalize)}"
  puts
  
  # Select perk at the beginning
  select_perk
  
  balance = $game_state.config['game']['starting_balance']
  player_score = 0
  computer_score = 0
  draws = 0
  used_weapons = []
  weapon_results = {}
  
  log_event("Game started - Difficulty: #{$game_state.difficulty}, Language: #{$game_state.language}")
  
  (1..$game_state.config['game']['rounds']).each do |round|
    unless $game_state.auto_mode
      puts "\n#{t('game.press_enter', round: round)}"
      gets
    end
        
    # Add round bonus to balance
    if round > 1
      bonus = $game_state.config['game']['round_bonuses'][round - 2]
      balance += bonus
      puts colorize(t('game.round_bonus', amount: bonus), Colors::CYAN)
    end
    
    # Attachment shop
    attachment_cost = attachment_shop(balance)
    balance -= attachment_cost if attachment_cost
    
    balance, result, weapon = play_round(weapons, round, balance)
    
    # Update scores and track data
    case result
    when :win
      player_score += 1
      weapon_results[weapon.name] = true if weapon
    when :loss
      computer_score += 1
      weapon_results[weapon.name] = false if weapon
    when :draw
      draws += 1
      weapon_results[weapon.name] = false if weapon
    end
    
    used_weapons << weapon.name if weapon
    
    # Display current score
    puts "\n#{colorize(t('game.current_score', player: player_score, computer: computer_score), Colors::BOLD)}"
    
    if weapon.nil?  # No weapons available
      break
    end
  end
  
  # Update profile
  update_profile(player_score, computer_score, draws, used_weapons, weapon_results)
  
  # Final result
  puts "\n#{colorize(t('game.game_over'), Colors::BOLD + Colors::BLUE)}"
  puts "=" * 50
  puts "#{t('game.final_score', player: player_score, computer: computer_score)}"
  
  if player_score > computer_score
    puts colorize(t('game.congratulations'), Colors::GREEN + Colors::BOLD)
  elsif player_score < computer_score
    puts colorize(t('game.better_luck'), Colors::RED + Colors::BOLD)
  else
    puts colorize(t('game.tie'), Colors::YELLOW + Colors::BOLD)
  end
  puts "=" * 50
  
  log_event("Game ended - Final score: Player #{player_score} - Computer #{computer_score}")
end

def update_profile(player_score, computer_score, draws, used_weapons, weapon_results)
  profile = $game_state.profile
  
  profile['total_games'] += 1
  
  if player_score > computer_score
    profile['wins'] += 1
  elsif player_score < computer_score
    profile['losses'] += 1
  else
    profile['draws'] += 1
  end
  
  # Track weapon usage and wins
  used_weapons.each do |weapon_name|
    profile['weapon_usage'][weapon_name] ||= 0
    profile['weapon_usage'][weapon_name] += 1
  end
  
  # Track weapon wins
  weapon_results.each do |weapon_name, won|
    profile['weapon_wins'][weapon_name] ||= 0
    profile['weapon_wins'][weapon_name] += 1 if won
  end
  
  # Update ELO ratings
  update_weapon_elo(profile, weapon_results)
  
  # Check achievements
  check_achievements(profile, player_score, computer_score, draws)
  
  # Save profile
  save_profile(profile)
end

def update_weapon_elo(profile, weapon_results)
  # Initialize ELO ratings if not present
  profile['weapon_elo'] ||= {}
  
  weapon_results.each do |weapon_name, won|
    # Initialize weapon ELO if not present
    profile['weapon_elo'][weapon_name] ||= 1200
    
    # Simple ELO calculation
    k_factor = 32
    expected_score = 0.5  # Assuming equal strength initially
    actual_score = won ? 1.0 : 0.0
    
    # Calculate new ELO
    new_elo = profile['weapon_elo'][weapon_name] + k_factor * (actual_score - expected_score)
    profile['weapon_elo'][weapon_name] = new_elo.round
  end
end

def check_achievements(profile, player_score, computer_score, draws)
  achievements = profile['achievements']
  
  # Economist achievement
  if !achievements.include?('economist') && player_score > 0
    achievements << 'economist'
    puts colorize("🏆 Achievement Unlocked: #{t('achievements.economist')}", Colors::GREEN)
  end
  
  # Streaker achievement
  if !achievements.include?('streaker') && player_score == 5 && computer_score == 0
    achievements << 'streaker'
    puts colorize("🏆 Achievement Unlocked: #{t('achievements.streaker')}", Colors::GREEN)
  end
  
  # Draw Master achievement
  if !achievements.include?('draw_master') && draws >= 2
    achievements << 'draw_master'
    puts colorize("🏆 Achievement Unlocked: #{t('achievements.draw_master')}", Colors::GREEN)
  end
end

def save_profile(profile)
  begin
    File.write('profile.json', JSON.pretty_generate(profile))
  rescue => e
    puts colorize("Error saving profile: #{e.message}", Colors::RED)
  end
end

def print_statistics
  profile = $game_state.profile
  
  puts "\n#{colorize(t('statistics.title'), Colors::BOLD + Colors::BLUE)}"
  puts "=" * 50
  
  total_games = profile['total_games']
  wins = profile['wins']
  losses = profile['losses']
  draws = profile['draws']
  
  puts "#{t('statistics.total_games', count: total_games)}"
  puts "#{t('statistics.wins', count: wins)}"
  puts "#{t('statistics.losses', count: losses)}"
  puts "#{t('statistics.draws', count: draws)}"
  
  if total_games > 0
    win_rate = (wins.to_f / total_games * 100).round(1)
    puts "#{t('statistics.win_rate', rate: win_rate)}"
  end
  
  # Most used weapon
  weapon_usage = profile['weapon_usage']
  if weapon_usage.any?
    most_used = weapon_usage.max_by { |_, count| count }
    puts "#{t('statistics.most_used_weapon', weapon: most_used[0], count: most_used[1])}"
  end
  
  # Top 5 Weapons by wins
  weapon_wins = profile['weapon_wins']
  if weapon_wins.any?
    puts "\n#{colorize(t('statistics.top_weapons'), Colors::BOLD)}"
    top_weapons = weapon_wins.sort_by { |_, wins| -wins }.first(5)
    top_weapons.each_with_index do |(weapon, wins), index|
      puts "#{index + 1}. #{weapon}: #{wins} #{t('statistics.wins_short')}"
    end
  end
  
  # Top 5 Weapons by ELO
  weapon_elo = profile['weapon_elo']
  if weapon_elo.any?
    puts "\n#{colorize(t('statistics.top_elo'), Colors::BOLD)}"
    top_elo = weapon_elo.sort_by { |_, elo| -elo }.first(5)
    top_elo.each_with_index do |(weapon, elo), index|
      puts "#{index + 1}. #{weapon}: #{elo} ELO"
    end
  end
  
  # Achievements
  puts "\n#{t('statistics.achievements')}"
  if profile['achievements'].any?
    profile['achievements'].each do |achievement|
      puts "🏆 #{t("achievements.#{achievement}")}"
    end
  else
    puts colorize(t('statistics.no_achievements'), Colors::YELLOW)
  end
  
  puts
end

def show_options_menu
  loop do
    puts "\n#{colorize(t('options.title'), Colors::BOLD + Colors::BLUE)}"
    puts "=" * 40
    puts "1. #{t('options.language')} (#{$game_state.settings['language']})"
    puts "2. #{t('options.difficulty')} (#{$game_state.settings['difficulty']})"
    puts "3. #{t('options.events')} (#{$game_state.settings['events_enabled'] ? t('options.enabled') : t('options.disabled')})"
    puts "4. #{t('options.colors')} (#{$game_state.settings['colored_output'] ? t('options.enabled') : t('options.disabled')})"
    puts "5. #{t('options.reset_profile')}"
    puts "0. #{t('options.back')}"
    
    choice = get_safe_input(t('options.choice_prompt'), 0..5)
    
    case choice
    when 0
      break
    when 1
      change_language
    when 2
      change_difficulty
    when 3
      toggle_events
    when 4
      toggle_colors
    when 5
      reset_profile
    end
  end
end

def change_language
  puts "\n#{t('options.select_language')}"
  puts "1. English (en)"
  puts "2. Türkçe (tr)"
  
  choice = get_safe_input(t('options.language_choice'), 1..2)
  languages = ['en', 'tr']
  new_language = languages[choice - 1]
  
  $game_state.settings['language'] = new_language
  $game_state.language = new_language
  save_settings($game_state.settings)
  
  puts colorize(t('options.language_changed'), Colors::GREEN)
end

def change_difficulty
  puts "\n#{t('options.select_difficulty')}"
  puts "1. Easy"
  puts "2. Normal"
  puts "3. Hard"
  
  choice = get_safe_input(t('options.difficulty_choice'), 1..3)
  difficulties = ['easy', 'normal', 'hard']
  new_difficulty = difficulties[choice - 1]
  
  $game_state.settings['difficulty'] = new_difficulty
  $game_state.difficulty = new_difficulty
  save_settings($game_state.settings)
  
  puts colorize(t('options.difficulty_changed'), Colors::GREEN)
end

def toggle_events
  $game_state.settings['events_enabled'] = !$game_state.settings['events_enabled']
  save_settings($game_state.settings)
  
  status = $game_state.settings['events_enabled'] ? t('options.enabled') : t('options.disabled')
  puts colorize(t('options.events_toggled', status: status), Colors::GREEN)
end

def toggle_colors
  $game_state.settings['colored_output'] = !$game_state.settings['colored_output']
  $game_state.no_color = !$game_state.settings['colored_output']
  save_settings($game_state.settings)
  
  status = $game_state.settings['colored_output'] ? t('options.enabled') : t('options.disabled')
  puts colorize(t('options.colors_toggled', status: status), Colors::GREEN)
end

def reset_profile
  puts "\n#{colorize(t('options.reset_warning'), Colors::RED)}"
  print "#{t('options.confirm_reset')} "
  confirm = gets.chomp.downcase
  
  if confirm == 'y' || confirm == 'e'
    $game_state.profile = create_default_profile
    save_profile($game_state.profile)
    puts colorize(t('options.profile_reset'), Colors::GREEN)
    log_event("Profile reset by user")
  else
    puts colorize(t('options.reset_cancelled'), Colors::YELLOW)
  end
end

def simulate_battles(weapons, simulation_count)
  puts "\n#{colorize(t('simulation.title'), Colors::BOLD + Colors::BLUE)}"
  puts "#{t('simulation.running', count: simulation_count)}"
  
  win_counts = Hash.new(0)
  total_battles = 0
  
  simulation_count.times do
    weapons.each_with_index do |weapon1, i|
      weapons.each_with_index do |weapon2, j|
        next if i == j
        
        # Apply random events to both weapons
        w1 = weapon1.dup
        w2 = weapon2.dup
        apply_random_event(w1)
        apply_random_event(w2)
        
        if w1.balanced_score > w2.balanced_score
          win_counts[w1.name] += 1
        end
        total_battles += 1
      end
    end
  end
  
  # Calculate win rates
  puts "\n#{colorize(t('simulation.results'), Colors::BOLD)}"
  puts "=" * 50
  
  win_rates = {}
  weapons.each do |weapon|
    wins = win_counts[weapon.name]
    win_rate = (wins.to_f / (weapons.size - 1) / simulation_count * 100).round(1)
    win_rates[weapon.name] = win_rate
  end
  
  # Sort by win rate
  win_rates.sort_by { |_, rate| -rate }.each do |weapon_name, win_rate|
    puts "#{t('simulation.weapon_win_rate', weapon: weapon_name, rate: win_rate)}"
  end
  
  puts
end

def menu(weapons)
  loop do
    puts "\n#{colorize(t('menu.title'), Colors::BOLD + Colors::BLUE)}"
    puts "=" * 40
    puts "1. #{t('menu.play')}"
    puts "2. #{t('menu.options')}"
    puts "3. #{t('menu.help')}"
    puts "4. #{t('menu.about')}"
    puts "5. #{t('menu.statistics')}"
    puts "6. #{t('menu.exit')}"
    puts "=" * 40
    
    choice = get_safe_input(t('menu.choice_prompt'), 1..6)
    
    case choice
    when 1
      play_game(weapons)
    when 2
      show_options_menu
    when 3
      puts "\n#{colorize(t('help.title'), Colors::BOLD + Colors::CYAN)}"
      puts "=" * 50
      puts t('help.content')
    when 4
      print_about(weapons)
    when 5
      print_statistics
    when 6
      puts "\n#{colorize(t('menu.goodbye'), Colors::GREEN)}"
      break
    end
  end
end

def parse_arguments
  options = {}
  
  OptionParser.new do |opts|
    opts.banner = "Usage: ruby ammo.rb [options]"
    
    opts.on("--diff DIFFICULTY", ["easy", "normal", "hard"], "Set difficulty level") do |diff|
      options[:difficulty] = diff
    end
    
    opts.on("--lang LANGUAGE", ["en", "tr"], "Set language") do |lang|
      options[:language] = lang
    end
    
    opts.on("--sim COUNT", Integer, "Run simulation mode") do |count|
      options[:simulation] = count
    end
    
    opts.on("--seed SEED", Integer, "Set random seed for reproducible results") do |seed|
      options[:seed] = seed
    end
    
    opts.on("--auto", "Enable auto mode (random selections, no delays)") do
      options[:auto] = true
    end
    
    opts.on("--no-color", "Disable colored output") do
      options[:no_color] = true
    end
    
    opts.on("-h", "--help", "Show this help message") do
      puts opts
      exit
    end
  end.parse!
  
  options
end

def main
  # Parse command line arguments
  options = parse_arguments
  
  # Set global settings
  $game_state.difficulty = options[:difficulty] || ENV['DIFF'] || 'normal'
  $game_state.language = options[:language] || 'en'
  $game_state.auto_mode = options[:auto] || false
  $game_state.no_color = options[:no_color] || false
  
  # Set random seed if provided
  if options[:seed]
    $game_state.seed = options[:seed]
    srand(options[:seed])
    log_event("Random seed set to: #{options[:seed]}")
  end
  
  # Load configuration
  load_config
  
  # Validate CSV file
  unless validate_csv_headers('Cs2.csv')
    puts colorize("Error: Invalid CSV file. Please check the required headers.", Colors::RED)
    return
  end
  
  # Load weapons
  puts colorize("Loading weapons from Cs2.csv...", Colors::CYAN)
  weapons = load_weapons('Cs2.csv')
  
  if weapons.empty?
    puts colorize("Error: No weapons loaded. Please check if Cs2.csv exists and has valid data.", Colors::RED)
    return
  end
  
  puts colorize("Successfully loaded #{weapons.size} weapons!", Colors::GREEN)
  log_event("Weapons loaded: #{weapons.size} weapons")
  
  # Check if simulation mode is requested
  if options[:simulation]
    simulate_battles(weapons, options[:simulation])
    return
  end
  
  # Start normal game
  menu(weapons)
end

# Run the game if this script is executed directly
if __FILE__ == $0
  main
end
