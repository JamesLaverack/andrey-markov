require "cinch"
require "andreymarkov/markov_table"
require "andreymarkov/configuration"

class AndreyMarkov
  include Cinch::Plugin
  timer 5, method: :timer

  listen_to :message

  def initialize(*args)
    super
    @markov_table  = MarkovTable.new
    @configuration = self.class.configuration
  end

  def self.configure(&blk)
    @@configuration = AndreyMarkovConfiguration.instance.configure &blk
  end

  def self.configuration
    @@configuration
  end

  def listen(m)
    if @configuration.useful_message?(m)
      respond_to_message(m.params[1])
    end
  end


  def timer
    p "timer"
    if should_speak?(AndreyMarkovConfiguration.instance.tick_probability)
      speak
    end
  end

  def respond_to_message(string_or_array)
    words = ensure_split(string_or_array)

    (1...words.length).each do |i|
      current_word = words[i-1]
      next_word = words[i]
      @markov_table.update(current_word, next_word)
    end

    @markov_table.update(words.last,:end)

    if should_speak?(@configuration.speak_percent)
      speak
    end

    @markov_table.save_dump
  end

  private

  def should_speak?(probability)
    c = Random.rand

    if AndreyMarkovConfiguration.instance.verbose
      puts "\nshould speak?\n"
      p c
      p probability
      p @markov_table.sufficiently_populated?
    end

    c < probability and @markov_table.sufficiently_populated?
  end

  def speak
    Channel(@configuration.channel).send @markov_table.make_sentence
  end

  def ensure_split(string_or_array)
    if string_or_array.respond_to? :split
      string_or_array = string_or_array.split
    end

    return string_or_array
  end
end
