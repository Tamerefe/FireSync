#!/usr/bin/env ruby

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

# Weapon struct for storing weapon data
Weapon = Struct.new(:name, :price, :damage, :firerate, :magazine, :falloff, :range, :recoil, :balanced_score, :dps)

def create_default_profile
  {
    'total_games' => 0,
    'wins' => 0,
    'losses' => 0,
    'draws' => 0,
    'weapon_usage' => {},
    'achievements' => []
  }
end

def load_profile
  profile_file = 'profile.json'
  if File.exist?(profile_file)
    begin
      JSON.parse(File.read(profile_file))
    rescue => e
      puts "#{Colors::RED}#{t('errors.profile_error', message: e.message)}#{Colors::RESET}"
      create_default_profile
    end
  else
    create_default_profile
  end
end

# Game state
class GameState
  attr_accessor :weapons, :config, :language, :difficulty, :profile, :current_perk, :current_attachments
  
  def initialize
    @weapons = []
    @config = {}
    @language = 'en'
    @difficulty = 'normal'
    @profile = create_default_profile
    @current_perk = nil
    @current_attachments = []
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
      puts "#{Colors::RED}Error loading config: #{e.message}#{Colors::RESET}"
      # Default config
      $game_state.config = {
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
    end
  else
    puts "#{Colors::YELLOW}Config file not found, using defaults#{Colors::RESET}"
    # Use default config above
  end
end

def load_language(lang)
  lang_file = "lang/#{lang}.yml"
  if File.exist?(lang_file)
    begin
      YAML.load_file(lang_file)
    rescue => e
      puts "#{Colors::RED}Error loading language file: #{e.message}#{Colors::RESET}"
      load_language('en') # Fallback to English
    end
  else
    puts "#{Colors::YELLOW}Language file not found, using English#{Colors::RESET}"
    load_language('en')
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
          puts "#{Colors::YELLOW}Warning: Skipping invalid weapon data: #{name}#{Colors::RESET}"
          next
        end
        
        # Create weapon and compute scores
        weapon = Weapon.new(name, price, damage, firerate, magazine, falloff, range, recoil)
        compute_balanced_score(weapon)
        compute_dps(weapon)
        weapons << weapon
        
      rescue => e
        puts "#{Colors::YELLOW}Warning: Error parsing weapon data: #{e.message}#{Colors::RESET}"
        next
      end
    end
  rescue => e
    puts "#{Colors::RED}#{t('errors.csv_error', message: e.message)}#{Colors::RESET}"
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
  $game_state.current_attachments.each do |attachment_key|
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
  events = $game_state.config['events']
  
  events.each do |event_key, event_data|
    if rand < event_data['probability']
      puts "#{Colors::CYAN}#{t("events.#{event_key}")}#{Colors::RESET}"
      
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
  end
  
  weapon
end

def print_about(weapons, page = 0)
  weapons_per_page = 15
  total_pages = (weapons.size / weapons_per_page.to_f).ceil
  
  puts "\n#{Colors::BOLD}#{Colors::BLUE}#{t('weapons.database_title')}#{Colors::RESET}"
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
    puts "\n#{Colors::CYAN}Navigation: #{Colors::RESET}"
    puts "n - Next page | p - Previous page | q - Quit"
    
    loop do
      print "> "
      input = gets.chomp.downcase
      
      case input
      when 'n'
        if page < total_pages - 1
          print_about(weapons, page + 1)
        else
          puts "#{Colors::YELLOW}Already on last page#{Colors::RESET}"
        end
        break
      when 'p'
        if page > 0
          print_about(weapons, page - 1)
        else
          puts "#{Colors::YELLOW}Already on first page#{Colors::RESET}"
        end
        break
      when 'q'
        break
      else
        puts "#{Colors::YELLOW}Invalid input#{Colors::RESET}"
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
      puts "#{Colors::RED}#{t('errors.invalid_number')}#{Colors::RESET}"
      next
    end
    
    choice = input.to_i
    
    # Check if choice is within valid range
    if valid_range && !valid_range.include?(choice)
      puts "#{Colors::RED}#{t('errors.invalid_range', min: valid_range.begin, max: valid_range.end)}#{Colors::RESET}"
      next
    end
    
    return choice
  end
end

def select_perk
  puts "\n#{Colors::BOLD}#{Colors::MAGENTA}#{t('perks.title')}#{Colors::RESET}"
  puts "=" * 50
  puts "1. #{t('perks.economist')}"
  puts "2. #{t('perks.control_master')}"
  puts "3. #{t('perks.long_shot')}"
  
  choice = get_safe_input(t('perks.choose_perk'), 1..3)
  
  perks = ['economist', 'control_master', 'long_shot']
  $game_state.current_perk = perks[choice - 1]
  
  puts "#{Colors::GREEN}Selected perk: #{$game_state.config['perks'][$game_state.current_perk]['name']}#{Colors::RESET}"
end

def attachment_shop(balance)
  puts "\n#{Colors::BOLD}#{Colors::MAGENTA}#{t('attachments.title')}#{Colors::RESET}"
  puts "=" * 50
  puts "#{t('game.balance', amount: balance)}"
  puts
  puts "1. #{t('attachments.extended_mag')}"
  puts "2. #{t('attachments.grip')}"
  puts "3. #{t('attachments.suppressor')}"
  puts "0. Skip"
  
  choice = get_safe_input(t('attachments.buy_attachment'), 0..3)
  return if choice == 0
  
  attachments = ['extended_mag', 'grip', 'suppressor']
  attachment_key = attachments[choice - 1]
  attachment = $game_state.config['attachments'][attachment_key]
  
  if attachment['price'] <= balance
    $game_state.current_attachments << attachment_key
    puts "#{Colors::GREEN}#{t('attachments.attachment_bought', name: attachment['name'])}#{Colors::RESET}"
    return attachment['price']
  else
    puts "#{Colors::RED}Insufficient balance!#{Colors::RESET}"
    return 0
  end
end

def display_weapons_for_round(weapons, group_range, balance)
  puts "\n#{Colors::BOLD}#{Colors::BLUE}ROUND #{(group_range.begin / 10 + 1).to_s} - #{t('round.available_weapons')}#{Colors::RESET}"
  puts "=" * 60
  puts "#{t('game.balance', amount: balance)}"
  puts
  
  available_weapons = weapons[group_range]
  
  if available_weapons.empty?
    puts "#{Colors::RED}No weapons available for this round!#{Colors::RESET}"
    return []
  end
  
  # Display weapons with numbers and DPS
  available_weapons.each_with_index do |weapon, index|
    number = index + 1
    affordable = weapon.price <= balance ? "#{Colors::GREEN}#{t('weapons.affordable')}#{Colors::RESET}" : "#{Colors::RED}#{t('weapons.not_affordable')}#{Colors::RESET}"
    printf("%2d. %-15s - $%-6d (DPS: %.1f) (%s)\n", number, weapon.name, weapon.price, weapon.dps, affordable)
  end
  
  available_weapons
end

def computer_select_weapon(available_weapons)
  # Sort weapons by balanced score
  sorted_weapons = available_weapons.sort_by(&:balanced_score)
  
  # Divide into three tiers
  tier_size = sorted_weapons.size / 3
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

def play_round(weapons, round_number, balance)
  puts "\n#{Colors::BOLD}#{Colors::CYAN}#{t('round.title', number: round_number)}#{Colors::RESET}"
  puts "=" * 50
  
  # Determine weapon group for this round
  weapon_groups = [
    0..9,    # Round 1: First 10 weapons
    10..16,  # Round 2: Next 7 weapons
    17..22,  # Round 3: Next 6 weapons
    23..29,  # Round 4: Next 7 weapons
    30..33   # Round 5: Last 4 weapons
  ]
  
  group_index = [round_number - 1, weapon_groups.size - 1].min
  group_range = weapon_groups[group_index]
  
  # Adjust range if we don't have enough weapons
  if group_range.end >= weapons.size
    group_range = group_range.begin..(weapons.size - 1)
  end
  
  # Display available weapons
  available_weapons = display_weapons_for_round(weapons, group_range, balance)
  
  if available_weapons.empty?
    puts "#{Colors::RED}No weapons available. Game over!#{Colors::RESET}"
    return balance, nil, nil
  end
  
  # Player selection
  player_weapon = nil
  loop do
    choice = get_safe_input(t('round.choose_weapon', count: available_weapons.size), 1..available_weapons.size)
    selected_weapon = available_weapons[choice - 1]
    
    if selected_weapon.price > balance
      puts "#{Colors::RED}#{t('round.insufficient_balance', needed: selected_weapon.price, have: balance)}#{Colors::RESET}"
      next
    end
    
    player_weapon = selected_weapon.dup
    balance -= selected_weapon.price
    break
  end
  
  # Apply perk and attachment effects
  player_weapon = apply_perk_effects(player_weapon)
  player_weapon = apply_attachment_effects(player_weapon)
  player_weapon = apply_random_event(player_weapon)
  
  puts "\n#{Colors::GREEN}#{t('round.you_selected', weapon: player_weapon.name, score: '%.2f' % player_weapon.balanced_score)}#{Colors::RESET}"
  
  # Computer selection
  computer_weapon = computer_select_weapon(available_weapons).dup
  computer_weapon = apply_random_event(computer_weapon)
  
  puts "#{Colors::RED}#{t('round.computer_selected', weapon: computer_weapon.name, score: '%.2f' % computer_weapon.balanced_score)}#{Colors::RESET}"
  
  # Determine winner
  puts "\n" + "-" * 40
  if player_weapon.balanced_score > computer_weapon.balanced_score
    puts "#{Colors::GREEN}#{Colors::BOLD}#{t('round.you_win')}#{Colors::RESET}"
    result = :win
    bonus = $game_state.config['economy']['win_bonus']
  elsif player_weapon.balanced_score < computer_weapon.balanced_score
    puts "#{Colors::RED}#{Colors::BOLD}#{t('round.computer_wins')}#{Colors::RESET}"
    result = :loss
    bonus = $game_state.config['economy']['loss_bonus']
  else
    puts "#{Colors::YELLOW}#{Colors::BOLD}#{t('round.draw')}#{Colors::RESET}"
    result = :draw
    bonus = 0
  end
  puts "-" * 40
  
  # Add bonus money
  balance += bonus
  puts "#{Colors::CYAN}Bonus: +$#{bonus}#{Colors::RESET}" if bonus > 0
  
  # Ask if player wants to sell weapon
  sell_price = (player_weapon.price * $game_state.config['economy']['sell_rate']).to_i
  print "#{t('economy.sell_weapon', amount: sell_price)}"
  sell_choice = gets.chomp.downcase
  
  if sell_choice == 'y' || sell_choice == 'e'
    balance += sell_price
    puts "#{Colors::GREEN}#{t('economy.weapon_sold', amount: sell_price)}#{Colors::RESET}"
  else
    puts "#{Colors::YELLOW}#{t('economy.weapon_not_sold')}#{Colors::RESET}"
  end
  
  sleep(1)
  
  return balance, result, player_weapon
end

def play_game(weapons)
  if weapons.empty?
    puts "#{Colors::RED}#{t('errors.no_weapons')}#{Colors::RESET}"
    return
  end
  
  puts "\n#{Colors::BOLD}#{Colors::BLUE}#{t('game.title')}#{Colors::RESET}"
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
  
  (1..$game_state.config['game']['rounds']).each do |round|
    puts "\n#{t('game.press_enter', round: round)}"
    gets
        
    # Add round bonus to balance
    if round > 1
      bonus = $game_state.config['game']['round_bonuses'][round - 2]
      balance += bonus
      puts "#{Colors::CYAN}#{t('game.round_bonus', amount: bonus)}#{Colors::RESET}"
    end
    
    # Attachment shop
    attachment_cost = attachment_shop(balance)
    balance -= attachment_cost if attachment_cost
    
    balance, result, weapon = play_round(weapons, round, balance)
    
    # Update scores and track data
    case result
    when :win
      player_score += 1
    when :loss
      computer_score += 1
    when :draw
      draws += 1
    end
    
    used_weapons << weapon.name if weapon
    
    # Display current score
    puts "\n#{Colors::BOLD}#{t('game.current_score', player: player_score, computer: computer_score)}#{Colors::RESET}"
    
    if weapon.nil?  # No weapons available
      break
    end
  end
  
  # Update profile
  update_profile(player_score, computer_score, draws, used_weapons)
  
  # Final result
  puts "\n#{Colors::BOLD}#{Colors::BLUE}#{t('game.game_over')}#{Colors::RESET}"
  puts "=" * 50
  puts "#{t('game.final_score', player: player_score, computer: computer_score)}"
  
  if player_score > computer_score
    puts "#{Colors::GREEN}#{Colors::BOLD}#{t('game.congratulations')}#{Colors::RESET}"
  elsif player_score < computer_score
    puts "#{Colors::RED}#{Colors::BOLD}#{t('game.better_luck')}#{Colors::RESET}"
  else
    puts "#{Colors::YELLOW}#{Colors::BOLD}#{t('game.tie')}#{Colors::RESET}"
  end
  puts "=" * 50
end

def load_profile
  profile_file = 'profile.json'
  if File.exist?(profile_file)
    begin
      JSON.parse(File.read(profile_file))
    rescue => e
      puts "#{Colors::RED}#{t('errors.profile_error', message: e.message)}#{Colors::RESET}"
      create_default_profile
    end
  else
    create_default_profile
  end
end

def create_default_profile
  {
    'total_games' => 0,
    'wins' => 0,
    'losses' => 0,
    'draws' => 0,
    'weapon_usage' => {},
    'achievements' => []
  }
end

def update_profile(player_score, computer_score, draws, used_weapons)
  profile = $game_state.profile
  
  profile['total_games'] += 1
  
  if player_score > computer_score
    profile['wins'] += 1
  elsif player_score < computer_score
    profile['losses'] += 1
  else
    profile['draws'] += 1
  end
  
  # Track weapon usage
  used_weapons.each do |weapon_name|
    profile['weapon_usage'][weapon_name] ||= 0
    profile['weapon_usage'][weapon_name] += 1
  end
  
  # Check achievements
  check_achievements(profile, player_score, computer_score, draws)
  
  # Save profile
  save_profile(profile)
end

def check_achievements(profile, player_score, computer_score, draws)
  achievements = profile['achievements']
  
  # Economist achievement
  if !achievements.include?('economist') && player_score > 0
    achievements << 'economist'
    puts "#{Colors::GREEN}🏆 Achievement Unlocked: #{t('achievements.economist')}#{Colors::RESET}"
  end
  
  # Streaker achievement
  if !achievements.include?('streaker') && player_score == 5 && computer_score == 0
    achievements << 'streaker'
    puts "#{Colors::GREEN}🏆 Achievement Unlocked: #{t('achievements.streaker')}#{Colors::RESET}"
  end
  
  # Draw Master achievement
  if !achievements.include?('draw_master') && draws >= 2
    achievements << 'draw_master'
    puts "#{Colors::GREEN}🏆 Achievement Unlocked: #{t('achievements.draw_master')}#{Colors::RESET}"
  end
end

def save_profile(profile)
  begin
    File.write('profile.json', JSON.pretty_generate(profile))
  rescue => e
    puts "#{Colors::RED}Error saving profile: #{e.message}#{Colors::RESET}"
  end
end

def print_statistics
  profile = $game_state.profile
  
  puts "\n#{Colors::BOLD}#{Colors::BLUE}#{t('statistics.title')}#{Colors::RESET}"
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
  
  # Achievements
  puts "\n#{t('statistics.achievements')}"
  if profile['achievements'].any?
    profile['achievements'].each do |achievement|
      puts "🏆 #{t("achievements.#{achievement}")}"
    end
  else
    puts "#{Colors::YELLOW}#{t('statistics.no_achievements')}#{Colors::RESET}"
  end
  
  puts
end

def simulate_battles(weapons, simulation_count)
  puts "\n#{Colors::BOLD}#{Colors::BLUE}#{t('simulation.title')}#{Colors::RESET}"
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
  puts "\n#{Colors::BOLD}#{t('simulation.results')}#{Colors::RESET}"
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
    puts "\n#{Colors::BOLD}#{Colors::BLUE}#{t('menu.title')}#{Colors::RESET}"
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
      puts "\n#{Colors::YELLOW}Options - Not implemented yet.#{Colors::RESET}"
    when 3
      puts "\n#{Colors::BOLD}#{Colors::CYAN}#{t('help.title')}#{Colors::RESET}"
      puts "=" * 50
      puts t('help.content')
    when 4
      print_about(weapons)
    when 5
      print_statistics
    when 6
      puts "\n#{Colors::GREEN}Thanks for playing! Goodbye!#{Colors::RESET}"
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
  
  # Load configuration
  load_config
  
  # Load weapons
  puts "#{Colors::CYAN}Loading weapons from Cs2.csv...#{Colors::RESET}"
  weapons = load_weapons('Cs2.csv')
  
  if weapons.empty?
    puts "#{Colors::RED}Error: No weapons loaded. Please check if Cs2.csv exists and has valid data.#{Colors::RESET}"
    return
  end
  
  puts "#{Colors::GREEN}Successfully loaded #{weapons.size} weapons!#{Colors::RESET}"
  
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
