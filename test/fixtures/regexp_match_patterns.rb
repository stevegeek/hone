# frozen_string_literal: true

# Test fixture for regexp_match pattern detection

class RegexpMatchPatterns
  # SHOULD flag: =~ in boolean context without using match data
  def should_flag_simple_match(str)
    if str =~ /pattern/
      puts "matched"
    end
  end

  # SHOULD flag: .match without using result
  def should_flag_match_method(str)
    if /pattern/.match(str)
      puts "matched"
    end
  end

  # Should NOT flag: result assigned to variable
  def should_not_flag_assigned_match(str)
    if m = str.match(/pattern/)
      m[1]
    end
  end

  # Should NOT flag: uses $1 global variable
  def should_not_flag_dollar_one(str)
    if str =~ /(\w+)/
      puts $1
    end
  end

  # Should NOT flag: uses $1 in raise (i18n pattern)
  def should_not_flag_dollar_one_in_raise(str, pattern)
    raise Error.new($1.to_sym, str) if str =~ pattern
  end

  # Should NOT flag: uses $2 global variable
  def should_not_flag_dollar_two(str)
    if str =~ /(\w+)\.(\w+)/
      puts "#{$1}.#{$2}"
    end
  end

  # Should NOT flag: named captures create variables
  def should_not_flag_named_captures(str)
    if /(?<name>\w+)/ =~ str
      puts name
    end
  end

  # SHOULD flag: unless with =~ and no $1 usage
  def should_flag_unless_simple(str)
    unless str =~ /pattern/
      puts "no match"
    end
  end

  # Should NOT flag: unless with =~ but $1 in else
  def should_not_flag_unless_with_dollar_one(str)
    unless str =~ /(\w+)/
      puts "no match"
    else
      puts $1
    end
  end

  # Should NOT flag: uses $~ MatchData global (strong_parameters pattern)
  def should_not_flag_dollar_tilde(key, permitted_key)
    if key =~ /\(\d+[if]?\)\z/
      return $~.pre_match == permitted_key
    end
  end

  # Should NOT flag: uses $& (matched string)
  def should_not_flag_dollar_ampersand(str)
    if str =~ /pattern/
      puts "matched: #{$&}"
    end
  end

  # Should NOT flag: uses $` (pre_match)
  def should_not_flag_dollar_backtick(str)
    if str =~ /pattern/
      puts "before: #{$`}"
    end
  end

  # Should NOT flag: uses $' (post_match)
  def should_not_flag_dollar_quote(str)
    if str =~ /pattern/
      puts "after: #{$'}"
    end
  end
end
