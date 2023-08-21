--  Display the contents of you library
--
--[====[

librarian
================
]====]
local dont_be_silly = false  --  'true' disables the "ook" part from the description of the return from hiding key.
local ook_start_x = 10       --  x position of where the "ook" key description appears, in case the script clashes with something else.

local gui = require 'gui'
local dialog = require 'gui.dialogs'
local widgets = require 'gui.widgets'
local guiScript = require 'gui.script'
local utils = require 'utils'
local Ui

--=====================================

local values = {[df.value_type.LAW] =
                {[-3] = "finds the idea of law abhorrent",
                 [-2] = "disdains the law",
                 [-1] = "does not respect the law",
                 [0] = "doesn't feel strongly about the law",
                 [1] = "respects the law",
                 [2] = "has a great deal of respect for the law",
                 [3] = "is an absolute believer in the rule of law"},    
                [df.value_type.LOYALTY] =
                {[-3] = "is disgusted by the idea of loyalty",
                 [-2] = "disdains loyalty",
                 [-1] = "views loyalty unfavorably",
                 [0] = "doesn't particularly value loyalty",
                 [1] = "values loyalty",
                 [2] = "greatly prizes loyalty",
                 [3] = "has the highest regard for loyalty"},
                [df.value_type.FAMILY] =
                {[-3] = "finds the idea of family loathsome",
                 [-2] = "lacks any respect for family",
                 [-1] = "is put off by family",
                 [0] = "does not care about family one way or the other",
                 [1] = "values family",
                 [2] = "values family greatly",
                 [3] = "sees family as one of the most important things in life"},
                [df.value_type.FRIENDSHIP] =
                {[-3] = "finds the whole idea of friendship disgusting",
                 [-2] = "is completely put off by the idea of friends",
                 [-1] = "finds friendship burdensome",
                 [0] = "does not care about friendship",
                 [1] = "thinks friendship is important",
                 [2] = "sees friendship as one of the finer things in life",
                 [3] = "believes friendship is the key to the ideal life"},
                [df.value_type.POWER] =
                {[-3] = "finds the acquisition and use of power abhorrent and would have all masters toppled",
                 [-2] = "hates those who wield power over others",
                 [-1] = "has a negative view of those who exercise power over others",
                 [0] = "doesn't find power particularly praiseworthy",
                 [1] = "respects power",
                 [2] = "sees power over others as something to strive for",
                 [3] = "believes that the acquisition of power over others is the ideal goal in life and worthy of the highest respect"},
                [df.value_type.TRUTH] =
                {[-3] = "is repelled by the idea of honesty and lies without compunction",
                 [-2] = "sees lying as an important means to an end",
                 [-1] = "finds blind honesty foolish",
                 [0] = "does not particularly value the truth",
                 [1] = "values honesty",
                 [2] = "believes that honesty is a high ideal",
                 [3] = "believes the truth is inviolable regardless of the cost"},
                [df.value_type.CUNNING] =
                {[-3] = "is utterly disgusted by guile and cunning",
                 [-2] = "holds shrewd and crafty individuals in the lowest esteem",
                 [-1] = "sees guile and cunning as indirect and somewhat worthless",
                 [0] = "does not really value cunning and guile",
                 [1] = "values cunning",
                 [2] = "greatly respects the shrewd and guileful",
                 [3] = "holds well-laid plans and shrewd deceptions in the highest regard"},
                [df.value_type.ELOQUENCE] =
                {[-3] = "sees artful speech and eloquence as a wasteful form of deliberate deception and treats it as such",
                 [-2] = "finds [him]self somewhat disgusted with eloquent speakers",
                 [-1] = "finds eloquence and artful speech off-putting",
                 [0] = "doesn't value eloquence so much",
                 [1] = "values eloquence",
                 [2] = "deeply respects eloquent speakers",
                 [3] = "believes that artful speech and eloquent expression are of the highest ideals"},
                [df.value_type.FAIRNESS] =
                {[-3] = "is disgusted by the idea of fairness and will freely cheat anybody at any time",
                 [-2] = "finds the idea of fair-dealing foolish and cheats whenever [he] finds it profitable",
                 [-1] = "sees life as unfair and doesn't mind it that way",
                 [0] = "does not care about fairness",  -- one way or the other?
                 [1] = "respects fair-dealing and fair-play",
                 [2] = "has great respect for fairness",
                 [3] = "holds fairness as one of the highest ideals and despises cheating of any kind"},
                [df.value_type.DECORUM] =
                {[-3] = "is affronted of the whole notion of maintaining decorum and finds so-called dignified people disgusting",
                 [-2] = "sees those that attempt to maintain dignified and proper behavior as vain and offensive",
                 [-1] = "finds maintaining decorum a silly, fumbling waste of time",
                 [0] = "doesn't care very much about decorum",
                 [1] = "values decorum, dignity and proper behavior",
                 [2] = "greatly respects those that observe decorum and maintain their dignity",
                 [3] = "views decorum as a high ideal and is deeply offended by those that fail to maintain it"},
                [df.value_type.TRADITION] =
                {[-3] = "is disgusted by tradition and would flout any [he] encounters if given a chance",
                 [-2] = "find the following of tradition foolish and limiting",
                 [-1] = "disregards tradition",
                 [0] = "doesn't have any strong feelings about tradition",
                 [1] = "values tradition",
                 [2] = "is a firm believer in the value of tradition",
                 [3] = "holds the maintenance of tradition as one of the highest ideals"},
                [df.value_type.ARTWORK] =
                {[-3] = "finds art offensive and would have it destroyed whenever possible",
                 [-2] = "sees the whole pursuit of art as silly",
                 [-1] = "finds artwork boring",
                 [0] = "doesn't care about art one way or another",
                 [1] = "values artwork",
                 [2] = "greatly respects artists and their work",
                 [3] = "believes that the creation and appreciation of artwork is one of the highest ideals"},
                [df.value_type.COOPERATION] =
                {[-3] = "is thoroughly disgusted by cooperation",
                 [-2] = "views cooperation as a low ideal not worthy of any respect",
                 [-1] = "dislikes cooperation",
                 [0] = "doesn't see cooperation as valuable",
                 [1] = "values cooperation",
                 [2] = "sees cooperation as very important in life",
                 [3] = "places cooperation as one of the highest ideals"},
                [df.value_type.INDEPENDENCE] =
                {[-3] = "hates freedom and would crush the independent spirit wherever it is found",
                 [-2] = "sees freedom and independence as completely worthless",
                 [-1] = "finds the idea of independence and freedom somewhat foolish",
                 [0] = "doesn't really value independence one way or another",
                 [1] = "values independence",
                 [2] = "treasures independence",
                 [3] = "believes that freedom and independence are completely non-negotiable and would fight to defend them"},
                [df.value_type.STOICISM] =
                {[-3] = "sees concealment of emotions as a betrayal and tries [his] best never to associate with such secretive fools",
                 [-2] = "feels that those who attempt to conceal their emotions are vain and foolish",
                 [-1] = "sees no value in holding back complaints and concealing emotions",
                 [0] = "doesn't see much value in being stoic",
                 [1] = "believes it is important to conceal emotions and refrain from complaining",
                 [2] = "thinks it is of the utmost importance to present a bold face and never grouse, complain, and even show emotion",
                 [3] = "views any show of emotion as offensive"},
                [df.value_type.INTROSPECTION] =
                {[-3] = "finds the whole idea of introspection completely offensive and contrary to the ideals of a life well-lived",
                 [-2] = "thinks that introspection is valueless and those that waste time in self-examination are deluded fools",
                 [-1] = "finds introspection to be a waste of time",
                 [0] = "doesn't really see the value in self-examination",
                 [1] = "sees introspection as important",
                 [2] = "deeply values introspection",
                 [3] = "feels that introspection and all forms of self-examination are the keys to a good life and worthy of respect"},
                [df.value_type.SELF_CONTROL] =
                {[-3] = "has abandoned any attempt at self-control and finds the whole concept deeply offensive",
                 [-2] = "sees the denial of impulses as a vain and foolish pursuit",
                 [-1] = "finds those that deny their impulses somewhat stiff",
                 [0] = "doesn't particularly value self-control",
                 [1] = "values self-control",
                 [2] = "finds moderation and self-control to be very important",
                 [3] = "believes that self-mastery and the denial of impulses are of the highest ideals"},
                [df.value_type.TRANQUILITY] =
                {[-3] = "is disgusted by tranquility and would that the world would constantly churn with noise and activity",
                 [-2] = "is greatly disturbed by quiet and a peaceful existence",
                 [-1] = "prefers a noisy, bustling life to boring days without activity",
                 [0] = "doesn't have a preference between tranquility and tumult",
                 [1] = "values tranquility and a peaceful day",
                 [2] = "strongly values tranquility and quiet",
                 [3] = "views tranquility as one of the highest ideals"},
                [df.value_type.HARMONY] =
                {[-3] = "believes deeply that chaos and disorder are the truest expressions of life and would disrupt harmony wherever it is found",
                 [-2] = "can't fathom why anyone would want to live in an orderly and harmonious society",
                 [-1] = "doesn't respect a society that has settled into harmony without debate and strife",
                 [0] = "sees equal parts of harmony and discord as parts of life",
                 [1] = "values a harmonious existence",
                 [2] = "strongly believes that a peaceful and ordered society without dissent is best",
                 [3] = "would have the world operate in complete harmony without the least bit of strife and disorder"},
                [df.value_type.MERRIMENT] =
                {[-3] = "is appalled by merrymaking, parties and other such worthless activities",
                 [-2] = "is disgusted by merrymakers",
                 [-1] = "sees merrymaking as a waste",
                 [0] = "doesn't really value merrymaking",
                 [1] = "finds merrymaking and parying worthwhile activities",
                 [2] = "truly values merrymaking and parties",
                 [3] = "believes that little is better in life than a good party"},
                [df.value_type.CRAFTSMANSHIP] =
                {[-3] = "views craftdwarfship with disgust and would desecrate a so-called masterwork or two if [he] could get away with it",
                 [-2] = "sees the pursuit of good craftdwarfship as a total waste",
                 [-1] = "considers craftdwarfship to be relatively worthless",
                 [0] = "doesn't particularly care about crafdwarfship",
                 [1] = "values good craftdwarfship",
                 [2] = "has a great deal of respect for worthy craftdwarfship",
                 [3] = "holds craftdwarfship to be of the highest ideals and celebrates talented artisans and their masterworks"},
                [df.value_type.MARTIAL_PROWESS] =
                {[-3] = "abhors those who pursue the mastery of weapons and skill with fighting",
                 [-2] = "thinks that the pursuit of the skills of warfare and fighting is a low pursuit indeed",
                 [-1] = "finds those that develop skills with weapons and fighting distasteful",
                 [0] = "does not really value skills related to fighting",
                 [1] = "values martial prowess",
                 [2] = "deeply respects skill at arms",
                 [3] = "believes that martial prowess defines the good character of an individual"},
                [df.value_type.SKILL] =
                {[-3] = "sees the whole idea of taking time to master a skill as appalling",
                 [-2] = "believes that the time taken to master a skill is a horrible waste",
                 [-1] = "finds the pursuit of skill mastery off-putting",
                 [0] = "doesn't care if others take the time to master skills",
                 [1] = "respects the development of skill",
                 [2] = "really respects those that take the time to master a skill",
                 [3] = "believes that the mastery of a skill is one of the highest pursuits"},
                [df.value_type.HARD_WORK] =
                {[-3] = "finds the proposition that one should work hard in life utterly abhorrent",
                 [-2] = "thinks working hard is an abject idiocy",
                 [-1] = "sees working hard as a foolish waste of time",
                 [0] = "doesn't really see the point of working hard",
                 [1] = "values hard work",
                 [2] = "deeply respects those that work hard at their labors",
                 [3] = "believes that hard work is one of the highest ideals and a key to the good life"},
                [df.value_type.SACRIFICE] =
                {[-3] = "thinks that the whole concept of sacrifice for others is truly disgusting",
                 [-2] = "finds sacrifice to be the height of folly",
                 [-1] = "sees sacrifice as wasteful and foolish",
                 [0] = "doesn't particularly respect sacrifice as a virtue",
                 [1] = "values sacrifice",
                 [2] = "believes that those who sacrifice for others should be deeply respected",
                 [3] = "sacrifice to be one of the highest ideals"},
                [df.value_type.COMPETITION] =
                {[-3] = "finds the very idea of competition obscene",
                 [-2] = "deeply dislikes competition",
                 [-1] = "sees competition as wasteful and silly",
                 [0] = "doesn't have strong views on competition",
                 [1] = "sees competition as reasonably important",
                 [2] = "views competition as a crucial driving force of the world",
                 [3] = "holds the idea of competition among the most important and would encourage it whenever possible"},
                [df.value_type.PERSEVERENCE] =
                {[-3] = "finds the notion that one would persevere through adversity completely abhorrent",
                 [-2] = "thinks there is something deeply wrong with people the persevere through adversity",
                 [-1] = "sees perseverance in the face of adversity as bull-headed and foolish",
                 [0] = "doesn't think much about the idea of perseverance",
                 [1] = "respects perseverance",
                 [2] = "greatly respects individuals that persevere through their trials and labors",
                 [3] = "believes that perseverance is one of the greatest qualities somebody can have"},
                [df.value_type.LEISURE_TIME] =
                {[-3] = "believes that those that take leisure time are evil and finds the whole idea disgusting",
                 [-2] = "is offended by leisure time and leisurely living",
                 [-1] = "finds leisure time wasteful", --  also "prefers a noisy, bustling life to boring days without activity",?
                 [0] = "doesn't think one way or the other about leisure time",
                 [1] = "values leisure time",
                 [2] = "treasures leisure time and thinks it is very important in life",
                 [3] = "believes it would be a fine thing if all time were leisure time"},
                [df.value_type.COMMERCE] =
                {[-3] = "holds the view that commerce is a vile obscenity",
                 [-2] = "finds those that engage in trade and commerce to be fairly disgusting",
                 [-1] = "is somewhat put off by trade and commerce",
                 [0] = "doesn't particularly respect commerce",
                 [1] = "respects commerce",
                 [2] = "really respects commerce and those that engage in trade",
                 [3] = "sees engaging in commerce as a high ideal in life"},
                [df.value_type.ROMANCE] =
                {[-3] = "finds even the abstract idea of romance repellent",
                 [-2] = "is somewhat disgusted by romance",
                 [-1] = "finds romance distasteful",
                 [0] = "doesn't care one way or the other about romance",
                 [1] = "values romance",
                 [2] = "thinks romance is very important in life",
                 [3] = "sees romance as one of the highest ideals"},
                [df.value_type.NATURE] =
                {[-3] = "would just as soon have nature and the great outdoors burned to ashes and converted into a great mining pit",
                 [-2] = "has a deep dislike for the natural world",
                 [-1] = "finds nature somewhat disturbing",
                 [0] = "doesn't care about nature one way or another",
                 [1] = "values nature",
                 [2] = "has a deep respect for animals, plants and the natural world",
                 [3] = "holds nature to be of greater value than most aspects of civilization"},
                [df.value_type.PEACE] =
                {[-3] = "thinks that the world should be engaged into perpetual warfare",
                 [-2] = "believes war is preferable to peace in general",
                 [-1] = "sees was as a useful means to an end",
                 [0] = "doesn't particularly care between war and peace",
                 [1] = "values peace over war",
                 [2] = "believes that peace is always preferable to war",
                 [3] = "believes that the idea of war is utterly repellent and would have peace at all costs"},
                [df.value_type.KNOWLEDGE] =
                {[-3] = "sees the attainment and preservation of knowledge as an offensive enterprise engaged in by arrogant fools",
                 [-2] = "thinks the quest for knowledge is a delusional fantasy",
                 [-1] = "finds the pursuit of knowledge to be a waste of effort",
                 [0] = "doesn't see the attainment of knowledge as important",
                 [1] = "values knowledge",
                 [2] = "views the pursuit of knowledge as deeply important",
                 [3] = "finds the quest for knowledge to be of the very highest value"}}
 
--=====================================

local knowledge =
  {[0] = {[df.knowledge_scholar_flags_0.philosophy_logic_formal_reasoning] =                "Philosophy, Logic, Formal reasoning",
          [df.knowledge_scholar_flags_0.philosophy_logic_deductive_reasoning] =             "Philosophy, Logic, Deductive reasoning",
          [df.knowledge_scholar_flags_0.philosophy_logic_syllogistic_logic] =               "Philosophy, Logic, Syllogistic logic",
          [df.knowledge_scholar_flags_0.philosophy_logic_hypothetical_syllogisms] =         "Philosophy, Logic, Hypothetical syllogisms",
          [df.knowledge_scholar_flags_0.philosophy_logic_propositional_logic] =             "Philosophy, Logic, Propositional",
          [df.knowledge_scholar_flags_0.philosophy_logic_dialectic_reasoning] =             "Philosophy, Logic, Dialectic reasoning",
          [df.knowledge_scholar_flags_0.philosophy_logic_analogical_inference] =            "Philosophy, Logic, Analogical inference",
          [df.knowledge_scholar_flags_0.philosophy_ethics_applied_medical] =                "Philosophy, Ethics, Medical",
          [df.knowledge_scholar_flags_0.philosophy_ethics_individual_value] =               "Philosophy, Ethics, Individual value",
          [df.knowledge_scholar_flags_0.philosophy_ethics_state_consequentialism] =         "Philosophy, Ethics, State consequentialism",
          [df.knowledge_scholar_flags_0.philosophy_epistemology_truth] =                    "Philosophy, Epistemology, Truth",
          [df.knowledge_scholar_flags_0.philosophy_epistemology_perception] =               "Philosophy, Epistemology, Perception",
          [df.knowledge_scholar_flags_0.philosophy_epistemology_justification] =            "Philosophy, Epistemology, Justification",
          [df.knowledge_scholar_flags_0.philosophy_epistemology_belief] =                   "Philosophy, Epistemology, Belief",
          [df.knowledge_scholar_flags_0.philosophy_metaphysics_existence] =                 "Philosophy, Metaphysics, Existence",
          [df.knowledge_scholar_flags_0.philosophy_metaphysics_time] =                      "Philosophy, Metaphysics, Time",
          [df.knowledge_scholar_flags_0.philosophy_metaphysics_mind_body] =                 "Philosophy, Metaphysics, Mind-body",
          [df.knowledge_scholar_flags_0.philosophy_metaphysics_objects_and_properties] =    "Philosophy, Metaphysics, Objects and properties",
          [df.knowledge_scholar_flags_0.philosophy_metaphysics_wholes_and_parts] =          "Philosophy, Metaphysics, Wholes and parts",
          [df.knowledge_scholar_flags_0.philosophy_metaphysics_events] =                    "Philosophy, Metaphysics, Events",
          [df.knowledge_scholar_flags_0.philosophy_metaphysics_processes] =                 "Philosophy, Metaphysics, Processes",
          [df.knowledge_scholar_flags_0.philosophy_metaphysics_causation] =                 "Philosophy, Metaphysics, Causation",
          [df.knowledge_scholar_flags_0.philosophy_ethics_applied_military] =               "Philosophy, Ethics applied, Military",
          [df.knowledge_scholar_flags_0.philosophy_ethics_applied_interpersonal_conduct] =  "Philosophy, Ethics applied, Interpersonal ethics",
          [df.knowledge_scholar_flags_0.philosophy_specialized_law] =                       "Philosophy, Specialized, Law",
          [df.knowledge_scholar_flags_0.philosophy_specialized_education] =                 "Philosophy, Specialized, Education",
          [df.knowledge_scholar_flags_0.philosophy_specialized_language_grammar] =          "Philosophy, Specialized language, Grammar",
          [df.knowledge_scholar_flags_0.philosophy_specialized_language_etymology] =        "Philosophy, Specialized language Etymology",
          [df.knowledge_scholar_flags_0.philosophy_specialized_politics_diplomacy] =        "Philosophy, Specialized politics, Diplomacy",
          [df.knowledge_scholar_flags_0.philosophy_specialized_politics_government_forms] = "Philosophy, Specialized politics, Government forms",
          [df.knowledge_scholar_flags_0.philosophy_specialized_politics_economic_policy] =  "Philosophy, Specialized politics, Economic policy",
          [df.knowledge_scholar_flags_0.philosophy_specialized_politics_social_welfare] =   "Philosophy, Specialized politics, Social welfare"},
   [1] = {[df.knowledge_scholar_flags_1.philosophy_logic_inductive_reasoning] =             "Philosophy, Logic, Inductive reasoning",
          [df.knowledge_scholar_flags_1.philosophy_logic_direct_inference] =                "Philosophy, Logic, Direct inference",
          [df.knowledge_scholar_flags_1.philosophy_aesthetics_nature_of_beauty] =           "Philosophy, Aesthetics, Nature of beauty",
          [df.knowledge_scholar_flags_1.philosophy_aesthetics_value_of_art] =               "Philosophy, Aesthetics, Value of art",
          [df.knowledge_scholar_flags_1.philosophy_specialized_language_dictionary] =       "Philosophy, Specialized language, Dictionary"},
   [2] = {[df.knowledge_scholar_flags_2.mathematics_method_proof_by_contradiction] =        "Mathematics, Method, Proof by contradiction",
          [df.knowledge_scholar_flags_2.mathematics_notation_zero] =                        "Mathematics, Notation, Zero",
          [df.knowledge_scholar_flags_2.mathematics_notation_negative_numbers] =            "Mathematics, Notation, Negative numbers",
          [df.knowledge_scholar_flags_2.mathematics_notation_large_numbers] =               "Mathematics, Notation, Scientific notation",
          [df.knowledge_scholar_flags_2.mathematics_notation_positional] =                  "Mathematics, Notation, Positional",
          [df.knowledge_scholar_flags_2.mathematics_geometry_basic_objects] =               "Mathematics, Geometry, Basic objects",
          [df.knowledge_scholar_flags_2.mathematics_method_exhaustion] =                    "Mathematics, Method, Exhaustion",
          [df.knowledge_scholar_flags_2.mathematics_geometry_similar_and_congruent_triangles] = "Mathematics, Geometry, Similar and congruent triangles",
          [df.knowledge_scholar_flags_2.mathematics_geometry_geometric_mean_theorem] =      "Mathematics, Geometry, Geometric mean theorem",
          [df.knowledge_scholar_flags_2.mathematics_geometry_isosceles_base_angles_equal] = "Mathematics, Geometry, Isosceles base angles equal",
          [df.knowledge_scholar_flags_2.mathematics_geometry_inscribed_triangle_on_diameter_is_right] = "Mathematics, Geometry, Inscribed triangle on diameter is right",
          [df.knowledge_scholar_flags_2.mathematics_geometry_pythagorean_theorem] =         "Mathematics, Geometry, Pythagorean theorem",
          [df.knowledge_scholar_flags_2.mathematics_geometry_pythagorean_triples_small] =   "Mathematics, Geometry, Pythagorean triples small",
          [df.knowledge_scholar_flags_2.mathematics_geometry_pythagorean_triples_3_digit] = "Mathematics, Geometry, Pythagorean triples 3 digit",
          [df.knowledge_scholar_flags_2.mathematics_geometry_pythagorean_triples_4_digit] = "Mathematics, Geometry, Pythagorean triples 4 digit",
          [df.knowledge_scholar_flags_2.mathematics_geometry_existence_of_incommensurable_ratios] = "Mathematics, Geometry, Irrational numbers",
          [df.knowledge_scholar_flags_2.mathematics_method_axiomatic_reasoning] =           "Mathematics, Method, Axiomatic reasoning",
          [df.knowledge_scholar_flags_2.mathematics_numbers_unique_prime_factorization] =   "Mathematics, Numbers, Unique prime factorization",
          [df.knowledge_scholar_flags_2.mathematics_numbers_algorithm_for_computing_gcd] =  "Mathematics, Numbers, Algorithm for computing GCD",
          [df.knowledge_scholar_flags_2.mathematics_geometry_volume_of_pyramid] =           "Mathematics, Geometry, Volume of pyramid",
          [df.knowledge_scholar_flags_2.mathematics_geometry_volume_of_cone] =              "Mathematics, Geometry, Volume of cone",
          [df.knowledge_scholar_flags_2.mathematics_geometry_volume_of_sphere] =            "Mathematics, Geometry, Volume of Sphere",
          [df.knowledge_scholar_flags_2.mathematics_geometry_pi_to_4_digits] =              "Mathematics, Geometry, Pi to 4 digits",
          [df.knowledge_scholar_flags_2.mathematics_numbers_division_algorithm] =           "Mathematics, Numbers, Division algorithm",
          [df.knowledge_scholar_flags_2.mathematics_geometry_table_of_chord_values] =       "Mathematics, Geometry, Chord tables",
          [df.knowledge_scholar_flags_2.mathematics_geometry_area_of_triangle_from_side_lengths] = "Mathematics, Geometry, Area of triangle from side lengths",
          [df.knowledge_scholar_flags_2.mathematics_geometry_area_of_circle] =              "Mathematics, Geometry, Area of circle",
          [df.knowledge_scholar_flags_2.mathematics_geometry_pi_to_6_digits] =              "Mathematics, Geometry, Pi to 6 digits",
          [df.knowledge_scholar_flags_2.mathematics_geometry_definitions_and_basic_properties_of_conic_sections] = "Mathematics, Geometry, Conic sections",
          [df.knowledge_scholar_flags_2.mathematics_numbers_chinese_remainder_algorithm] =  "Mathematics, Numbers, Chinese remainder algorithm",
          [df.knowledge_scholar_flags_2.mathematics_geometry_area_enclosed_by_line_and_parabola] = "Mathematics, Geometry, Area enclosed by line and parabola",
          [df.knowledge_scholar_flags_2.mathematics_numbers_sieve_algorithm_for_primes] =   "Mathematics, Numbers, Sieve algorithm for primes"},
   [3] = {[df.knowledge_scholar_flags_3.mathematics_numbers_root_2_to_5_digits] =           "Mathematics, Numbers, Approximation of root 2",
          [df.knowledge_scholar_flags_3.mathematics_numbers_infinite_primes] =              "Mathematics, Numbers, Euclid's Theorem",
          [df.knowledge_scholar_flags_3.mathematics_numbers_root_2_irrational] =            "Mathematics, Numbers Irrationality of root 2",
          [df.knowledge_scholar_flags_3.mathematics_geometry_surface_area_of_sphere] =      "Mathematics, Gometry, Surface area of sphere",
          [df.knowledge_scholar_flags_3.mathematics_algebra_finite_summation_formulas] =    "Mathematics, Algebra, Large sums",
          [df.knowledge_scholar_flags_3.mathematics_algebra_solving_linear_systems] =       "Mathematics, Algebra, Systems of equations",
          [df.knowledge_scholar_flags_3.mathematics_algebra_balancing_and_completion] =     "Mathematics, Algbra, Balancing and completion",
          [df.knowledge_scholar_flags_3.mathematics_algebra_quadratic_by_completing_square] = "Mathematics, Algebra, Quadratic by completing square",
          [df.knowledge_scholar_flags_3.mathematics_algebra_quadratic_formula] =            "Mathematics, Algebra, Quadratic formula",
          [df.knowledge_scholar_flags_3.mathematics_notation_syncopated_algebra] =          "Mathematics, Notation, Syncopated algebra",
          [df.knowledge_scholar_flags_3.mathematics_geometry_law_of_sines] =                "Mathematics, Geometry, Law of sines",
          [df.knowledge_scholar_flags_3.mathematics_geometry_angle_sum_difference_trig_identities] = "Mathematics, Geometry, Sum-difference trig identities",
          [df.knowledge_scholar_flags_3.mathematics_algebra_pascals_triangle] =             "Mathematics, Algebra, Pascal's triangle",
          [df.knowledge_scholar_flags_3.mathematics_algebra_solving_higher_order_polynomials] = "Mathematics, Algebra, Solving higher order polynomials",
          [df.knowledge_scholar_flags_3.mathematics_notation_early_symbols_for_operations] = "Mathematics, Notation, Symbol for addition",
          [df.knowledge_scholar_flags_3.mathematics_algebra_divergence_of_harmonic_series] = "Mathematics, Algebra, Divergence of harmonic series",
          [df.knowledge_scholar_flags_3.mathematics_geometry_properties_of_chords] =        "Mathematics, Geometry, Properties of chords"},
   [4] = {[df.knowledge_scholar_flags_4.history_sourcing_basic_reliability] =               "History, Sourcing, Source reliability",
          [df.knowledge_scholar_flags_4.history_sourcing_role_of_systemic_bias] =           "History, Sourcing, Role of systemic bias",
          [df.knowledge_scholar_flags_4.history_sourcing_role_of_state_bias_and_propaganda] = "History, Sourcing, Role of state bias and propaganda",
          [df.knowledge_scholar_flags_4.history_sourcing_personal_interviews] =             "History, Sourcing, Personal interviews",
          [df.knowledge_scholar_flags_4.history_theory_historical_causation] =              "History, Theory, Historical causation",
          [df.knowledge_scholar_flags_4.history_theory_historical_cycles] =                 "History, Theory, Historical cycles",
          [df.knowledge_scholar_flags_4.history_theory_social_cohesion] =                   "History, Theory, Sociology",
          [df.knowledge_scholar_flags_4.history_theory_social_conflict] =                   "History, Theory, Social conflict",
          [df.knowledge_scholar_flags_4.history_form_biography] =                           "History, Form, Biography",
          [df.knowledge_scholar_flags_4.history_form_comparative_biography] =               "History, Form, Comparative biography",
          [df.knowledge_scholar_flags_4.history_form_biographical_dictionaries] =           "History, Form, Biographical dictionaries",
          [df.knowledge_scholar_flags_4.history_form_autobiographical_adventure] =          "History, Form, Autobiographical adventure",
          [df.knowledge_scholar_flags_4.history_form_genealogy] =                           "History, Form, Genealogy",
          [df.knowledge_scholar_flags_4.history_form_encyclopedia] =                        "History, Form, Encyclopedia",
          [df.knowledge_scholar_flags_4.history_form_cultural_history] =                    "History, Form, Cultural history",
          [df.knowledge_scholar_flags_4.history_form_cultural_comparison] =                 "History, Form, Comparative anthropology",
          [df.knowledge_scholar_flags_4.history_sourcing_role_of_cultural_differences] =    "History, Sourcing, Role of cultural differences",
          [df.knowledge_scholar_flags_4.history_form_alternate_history] =                   "History, Form, Alternate history",
          [df.knowledge_scholar_flags_4.history_sourcing_basic_archaeology] =               "History, Sourcing, Archaeology",
          [df.knowledge_scholar_flags_4.history_form_treatise_on_tech_evolution] =          "History, Form, Treatise on tech evolution"},
   [5] = {[df.knowledge_scholar_flags_5.astronomy_phases_of_the_moon] =                     "Astronomy, -, Phases of the moon",
          [df.knowledge_scholar_flags_5.astronomy_summer_winter_moon] =                     "Astronomy, -, Summer winter moon",
          [df.knowledge_scholar_flags_5.astronomy_path_of_the_moon] =                       "Astronomy, -, Path of the moon",
          [df.knowledge_scholar_flags_5.astronomy_tides_and_the_moon] =                     "Astronomy, -, Tides and the moon",
          [df.knowledge_scholar_flags_5.astronomy_height_of_tides_vs_moon_and_sun] =        "Astronomy, -, Tides and the moon",
          [df.knowledge_scholar_flags_5.astronomy_summer_winter_sun] =                      "Astronomy, -, Summer winter sun",
          [df.knowledge_scholar_flags_5.astronomy_relationship_between_lunar_solar_year] =  "Astronomy, -, Relationship between lunar solar year",
          [df.knowledge_scholar_flags_5.astronomy_daylight_variation_with_solar_year] =     "Astronomy, -, Daylight variation with solar year",
          [df.knowledge_scholar_flags_5.astronomy_geocentric_model] =                       "Astronomy, -, Geocentric model",
          [df.knowledge_scholar_flags_5.astronomy_heliocentric_model] =                     "Astronomy, -, Heliocentric model",
          [df.knowledge_scholar_flags_5.astronomy_dates_of_lunar_and_solar_eclipses] =      "Astronomy, -, Dates of lunar and solar eclipses",
          [df.knowledge_scholar_flags_5.astronomy_star_charts] =                            "Astronomy, -, Astrography",
          [df.knowledge_scholar_flags_5.astronomy_star_catalogues_100] =                    "Astronomy, -, Star catalogues 100",
          [df.knowledge_scholar_flags_5.astronomy_star_catalogues_1000] =                   "Astronomy, -, Star catalogues 1000",
          [df.knowledge_scholar_flags_5.astronomy_star_color_classification] =              "Astronomy, -, Stellar Spectroscopy",
          [df.knowledge_scholar_flags_5.astronomy_star_magnitude_classification] =          "Astronomy, -, Star magnitude classification",
          [df.knowledge_scholar_flags_5.astronomy_shape_of_the_world] =                     "Astronomy, -, Shape of the world",
          [df.knowledge_scholar_flags_5.astronomy_precession_of_equinoxes] =                "Astronomy, -, Precession of equinoxes",
          [df.knowledge_scholar_flags_5.astronomy_method_empirical_observation] =           "Astronomy, Method, Empirical observation",
          [df.knowledge_scholar_flags_5.astronomy_method_path_models] =                     "Astronomy, Method, Path models"},
   [6] = {[df.knowledge_scholar_flags_6.naturalist_method_dissection] =                     "Naturalist, Method, Dissection",
          [df.knowledge_scholar_flags_6.naturalist_observation_anatomy] =                   "Naturalist, Observation, Anatomy",
          [df.knowledge_scholar_flags_6.naturalist_theory_comparative_anatomy] =            "Naturalist, Theory, Comparative anatomy",
          [df.knowledge_scholar_flags_6.naturalist_theory_classification_by_physical_features] = "Naturalist, Theory, Physical taxonomy",
          [df.knowledge_scholar_flags_6.naturalist_observation_migration_patterns] =        "Naturalist, Observation, Migration patterns",
          [df.knowledge_scholar_flags_6.naturalist_observation_reproductive_behavior] =     "Naturalist, Observation, Reproductive behavior",
          [df.knowledge_scholar_flags_6.naturalist_observation_foraging_behavior_and_diet] = "Naturalist, Observation, Foraging behavior",
          [df.knowledge_scholar_flags_6.naturalist_theory_food_chain] =                     "Naturalist, Theory, Food chain",
          [df.knowledge_scholar_flags_6.naturalist_observation_social_behavior] =           "Naturalist, Observation, Social behavior",
          [df.knowledge_scholar_flags_6.naturalist_observation_diseases] =                  "Naturalist, Observation, Veterinary medicine",
          [df.knowledge_scholar_flags_6.naturalist_theory_climactic_adaptation] =           "Naturalist, Theory, Climactic adaptation",
          [df.knowledge_scholar_flags_6.naturalist_observation_embriological_development] = "Naturalist, Observation, Embryology",
          [df.knowledge_scholar_flags_6.naturalist_theory_struggle_for_existence] =         "Naturalist, Theory, Struggle for existence"},
   [7] = {[df.knowledge_scholar_flags_7.chemistry_classification_combustibles] =            "Chemistry, Classification, Combustibles",
          [df.knowledge_scholar_flags_7.chemistry_classification_ores] =                    "Chemistry, Classification, Ores",
          [df.knowledge_scholar_flags_7.chemistry_metallurgy_alloys] =                      "Chemistry, Metallurgy, Alloys",
          [df.knowledge_scholar_flags_7.chemistry_classification_scratch_test] =            "Chemistry, Classification, Scratch test",
          [df.knowledge_scholar_flags_7.chemistry_classification_elemental_theory] =        "Chemistry, Classification, Elemental theory",
          [df.knowledge_scholar_flags_7.chemistry_chemicals_adhesives] =                    "Chemistry, Chemicals, Adhesives",
          [df.knowledge_scholar_flags_7.chemistry_laboratory_blast_furnace] =               "Chemistry, Laboratory, Blast furnace",
          [df.knowledge_scholar_flags_7.chemistry_laboratory_alembic] =                     "Chemistry, Laboratory, Alembic",
          [df.knowledge_scholar_flags_7.chemistry_laboratory_theory_of_liquid_liquid_extraction] = "Chemistry, Laboratory, Theory of liquid liquid extraction",
          [df.knowledge_scholar_flags_7.chemistry_laboratory_theory_of_distillation] =      "Chemistry, Laboratory, Theory of distillation",
          [df.knowledge_scholar_flags_7.chemistry_laboratory_theory_of_evaporation] =       "Chemistry, Laboratory, Theory of evaporation",
          [df.knowledge_scholar_flags_7.chemistry_classification_alkali_and_acids] =        "Chemistry, Classification, Alkali and acids",
          [df.knowledge_scholar_flags_7.chemistry_laboratory_systematic_experiments] =      "Chemistry, Laboratory, Systematic experiments",
          [df.knowledge_scholar_flags_7.chemistry_laboratory_glass_flask] =                 "Chemistry, Laboratory, Glass flask",
          [df.knowledge_scholar_flags_7.chemistry_laboratory_glass_beaker] =                "Chemistry, Laboratory, Glass beaker",
          [df.knowledge_scholar_flags_7.chemistry_laboratory_glass_vial] =                  "Chemistry, Laboratory, Glass vial",
          [df.knowledge_scholar_flags_7.chemistry_laboratory_glass_funnel] =                "Chemistry, Laboratory, Glass funnel",
          [df.knowledge_scholar_flags_7.chemistry_laboratory_crucible] =                    "Chemistry, Laboratory, Crucible",
          [df.knowledge_scholar_flags_7.chemistry_chemicals_nitric_acid] =                  "Chemistry, Chemicals, Spirit of niter",
          [df.knowledge_scholar_flags_7.chemistry_chemicals_sulfuric_acid] =                "Chemistry, Chemicals, Oil of vitriol",
          [df.knowledge_scholar_flags_7.chemistry_chemicals_aqua_regia] =                   "Chemistry, Chemicals, Aqua regia",
          [df.knowledge_scholar_flags_7.chemistry_laboratory_glass_ampoule] =               "Chemistry, Laboratory, Glass ampoule",
          [df.knowledge_scholar_flags_7.chemistry_laboratory_glass_retort] =                "Chemistry, Laboratory, Glass retort",
          [df.knowledge_scholar_flags_7.chemistry_laboratory_lab_ovens] =                   "Chemistry, Laboratory, Lab ovens"},
   [8] = {[df.knowledge_scholar_flags_8.geography_surveying_basic] =                        "Geography, Surveying, Basic",
          [df.knowledge_scholar_flags_8.geography_surveying_staff] =                        "Geography, Surveying, Surveying staff",
          [df.knowledge_scholar_flags_8.geography_cartography_basic] =                      "Geography, Cartography, Basic",
          [df.knowledge_scholar_flags_8.geography_surveying_triangulation] =                "Geography, Surveying, Triangulation",
          [df.knowledge_scholar_flags_8.geography_surveying_cartographical] =               "Geography, Surveying, Cartographical surveying",
          [df.knowledge_scholar_flags_8.geography_surveying_land] =                         "Geography, Surveying, Land surveying",
          [df.knowledge_scholar_flags_8.geography_surveying_military] =                     "Geography, Surveying, Military surveying",
          [df.knowledge_scholar_flags_8.geography_surveying_engineering] =                  "Geography, Surveying, Engineering surveying",
          [df.knowledge_scholar_flags_8.geography_cartography_geological] =                 "Geography, Cartography, Geological",
          [df.knowledge_scholar_flags_8.geography_cartography_grid_system] =                "Geography, Cartography, Grid system",
          [df.knowledge_scholar_flags_8.geography_cartography_distance_scale] =             "Geography, Cartography, Distance scale",
          [df.knowledge_scholar_flags_8.geography_cartography_height_measurements] =        "Geography, Cartography, Height measurements",
          [df.knowledge_scholar_flags_8.geography_method_economic_data_collection] =        "Geography, Methods, Econometrics",
          [df.knowledge_scholar_flags_8.geography_cartography_economic] =                   "Geography, Cartography, Economic",
          [df.knowledge_scholar_flags_8.geography_form_atlas] =                             "Geography, Form, Atlas",
          [df.knowledge_scholar_flags_8.geography_theory_delta_formation] =                 "Geography, Theory, Delta formation",
          [df.knowledge_scholar_flags_8.geography_theory_wind_patterns] =                   "Geography, Theory, Anemology (Wind patterns)",
          [df.knowledge_scholar_flags_8.geography_theory_origin_of_rainfall_from_evap_condense] = "Geography, Theory, Origin of rainfall from evap condense",
          [df.knowledge_scholar_flags_8.geography_theory_water_cycle] =                     "Geography, Theory, Water cycle",
          [df.knowledge_scholar_flags_8.geography_theory_latitude_climate_zones] =          "Geography, Theory, Latitude climate zones",
          [df.knowledge_scholar_flags_8.geography_cartography_accurate_maps] =              "Geography, Cartography, Accurate maps",
          [df.knowledge_scholar_flags_8.geography_cartography_map_projections] =            "Geography, Cartography, Map projections"},
   [9] = {[df.knowledge_scholar_flags_9.medicine_theory_disease_and_fouled_water] =         "Medicine, Theory, Disease and fouled water",
          [df.knowledge_scholar_flags_9.medicine_method_physical_examination] =             "Medicine, Method, Physical examination",
          [df.knowledge_scholar_flags_9.medicine_method_autopsy] =                          "Medicine, Method, Autopsy",
          [df.knowledge_scholar_flags_9.medicine_theory_prognosis] =                        "Medicine, Theory, Prognosis",
          [df.knowledge_scholar_flags_9.medicine_tool_herbal_remedies] =                    "Medicine, Tool, Herbal remedies",
          [df.knowledge_scholar_flags_9.medicine_tool_animal_remedies] =                    "Medicine, Tool, Animal remedies",
          [df.knowledge_scholar_flags_9.medicine_tool_mineral_remedies] =                   "Medicine, Tool, Mineral remedies",
          [df.knowledge_scholar_flags_9.medicine_tool_bandages] =                           "Medicine, Tool, Bandages",
          [df.knowledge_scholar_flags_9.medicine_theory_disease_classification] =           "Medicine, Theory, Pathology",
          [df.knowledge_scholar_flags_9.medicine_theory_toxicology] =                       "Medicine, Theory, Toxicology",
          [df.knowledge_scholar_flags_9.medicine_theory_acute_and_chronic_conditions] =     "Medicine, Theory, Acute and chronic conditions",
          [df.knowledge_scholar_flags_9.medicine_theory_endemic_disease] =                  "Medicine, Theory, Endemic disease",
          [df.knowledge_scholar_flags_9.medicine_theory_epidemic_disease] =                 "Medicine, Theory, Epidemic disease",
          [df.knowledge_scholar_flags_9.medicine_theory_exacerbation] =                     "Medicine, Theory, Exacerbation",
          [df.knowledge_scholar_flags_9.medicine_theory_paroxysm] =                         "Medicine, Theory, Paroxysm",
          [df.knowledge_scholar_flags_9.medicine_theory_relapse] =                          "Medicine, Theory, Relapse",
          [df.knowledge_scholar_flags_9.medicine_theory_convalescence] =                    "Medicine, Theory, Convalescence",
          [df.knowledge_scholar_flags_9.medicine_method_treatment_of_traumatic_injuries] =  "Medicine, Method, Traumatic injury treatment",
          [df.knowledge_scholar_flags_9.medicine_method_fracture_treatment] =               "Medicine, Method, Fracture treatment",
          [df.knowledge_scholar_flags_9.medicine_theory_fracture_classification] =          "Medicine, Theory, Fracture classification",
          [df.knowledge_scholar_flags_9.medicine_tool_traction_bench] =                     "Medicine, Tool, Traction bench",
          [df.knowledge_scholar_flags_9.medicine_method_fracture_immobilization] =          "Medicine, Method, Fracture immobilization",
          [df.knowledge_scholar_flags_9.medicine_tool_orthopedic_cast] =                    "Medicine, Tool, Orthopedic cast",
          [df.knowledge_scholar_flags_9.medicine_method_surgery_excision] =                 "Medicine, Method, Surgery excision",
          [df.knowledge_scholar_flags_9.medicine_method_surgery_incision] =                 "Medicine, Method, Surgery incision",
          [df.knowledge_scholar_flags_9.medicine_method_hernia_surgery] =                   "Medicine, Method, Hernia surgery",
          [df.knowledge_scholar_flags_9.medicine_method_tracheotomy_surgery] =              "Medicine, Method, Tracheotomy surgery",
          [df.knowledge_scholar_flags_9.medicine_method_lithotomy_surgery] =                "Medicine, Method, Lithotomy surgery",
          [df.knowledge_scholar_flags_9.medicine_method_surgery_scraping] =                 "Medicine, Method, Surgery scraping",
          [df.knowledge_scholar_flags_9.medicine_method_surgery_draining] =                 "Medicine, Method, Surgery draining",
          [df.knowledge_scholar_flags_9.medicine_method_surgery_probing] =                  "Medicine, Method, Surgery probing",
          [df.knowledge_scholar_flags_9.medicine_method_surgery_suturing] =                 "Medicine, Method, Surgery suturing"},
   [10] = {[df.knowledge_scholar_flags_10.medicine_method_surgery_ligature] =               "Medicine, Method, Surgery ligature",
           [df.knowledge_scholar_flags_10.medicine_theory_surgical_models] =                "Medicine, Theory, Surgical models",
           [df.knowledge_scholar_flags_10.medicine_tool_mud_bags_as_surgical_models] =      "Medicine, Tool, Mud bags as surgical models",
           [df.knowledge_scholar_flags_10.medicine_tool_plants_as_surgical_models] =        "Medicine, Tool, Plants as surgical models",
           [df.knowledge_scholar_flags_10.medicine_tool_animals_as_surgical_models] =       "Medicine, Tool, Plants as surgical models",
           [df.knowledge_scholar_flags_10.medicine_theory_specialized_surgical_instruments] = "Medicine, Theory, Specialized surgical instruments",
           [df.knowledge_scholar_flags_10.medicine_tool_forceps] =                          "Medicine, Tool, Forceps",
           [df.knowledge_scholar_flags_10.medicine_tool_scalpel] =                          "Medicine, Tool, Scalpel",
           [df.knowledge_scholar_flags_10.medicine_tool_surgical_scissors] =                "Medicine, Tool, Surgical scissors",
           [df.knowledge_scholar_flags_10.medicine_tool_surgical_needles] =                 "Medicine, Tool, Surgical needles",
           [df.knowledge_scholar_flags_10.medicine_method_cataract_surgery] =               "Medicine, Method, Cataract surgery",
           [df.knowledge_scholar_flags_10.medicine_method_cauterization] =                  "Medicine, Method, Cauterization",
           [df.knowledge_scholar_flags_10.medicine_method_anesthesia] =                     "Medicine, Method, Anesthesia",
           [df.knowledge_scholar_flags_10.medicine_theory_pulmonary_medicine] =             "Medicine, Theory, Pulmonary medicine",
           [df.knowledge_scholar_flags_10.medicine_theory_anatomical_studies] =             "Medicine, Theory, Anatomical studies",
           [df.knowledge_scholar_flags_10.medicine_theory_classification_of_bodily_fluids] = "Medicine, Theory, Classification of bodily fluids",
           [df.knowledge_scholar_flags_10.medicine_theory_eye_anatomy] =                    "Medicine, Theory, Eye anatomy",
           [df.knowledge_scholar_flags_10.medicine_theory_motor_vs_sensory_nerves] =        "Medicine, Theory, Motor vs sensory nerves",
           [df.knowledge_scholar_flags_10.medicine_theory_nervous_system_function] =        "Medicine, Theory, Nervous system function",
           [df.knowledge_scholar_flags_10.medicine_theory_reaction_time] =                  "Medicine, Theory, Reaction time",
           [df.knowledge_scholar_flags_10.medicine_theory_blood_vessels] =                  "Medicine, Theory, Blood vessels",
           [df.knowledge_scholar_flags_10.medicine_theory_pulmonary_circulation] =          "Medicine, Theory, Pulmonary circulation",
           [df.knowledge_scholar_flags_10.medicine_theory_comparative_anatomy] =            "Medicine, Theory, Comparative anatomy",
           [df.knowledge_scholar_flags_10.medicine_theory_the_voice] =                      "Medicine, Theory, The voice",
           [df.knowledge_scholar_flags_10.medicine_theory_classification_of_muscles] =      "Medicine, Theory, Classification of muscles",
           [df.knowledge_scholar_flags_10.medicine_theory_classification_of_mental_illnesses] = "Medicine, Classification of mental illnesses",
           [df.knowledge_scholar_flags_10.medicine_theory_treatment_of_mental_illnesses] =  "Medicine, Treatment of mental illnesses",
           [df.knowledge_scholar_flags_10.medicine_tool_dedicated_hospitals] =              "Medicine, Tool, Dedicated hospitals",
           [df.knowledge_scholar_flags_10.medicine_method_professional_hospital_staff] =    "Medicine, Method, Professional hospital staff",
           [df.knowledge_scholar_flags_10.medicine_method_specialized_wards] =              "Medicine, Method, Specialized wards",
           [df.knowledge_scholar_flags_10.medicine_method_hospital_lab] =                   "Medicine, Method, Hospital lab",
           [df.knowledge_scholar_flags_10.medicine_method_medical_school] =                 "Medicine, Method, Medical school"},
   [11] = {[df.knowledge_scholar_flags_11.medicine_method_asylum_for_mentally_ill] =        "Medicine, Method, Asylum for mentally ill"},
   [12] = {[df.knowledge_scholar_flags_12.engineering_horology_shadow_clock] =              "Engineering, Horology, Shadow clock",
           [df.knowledge_scholar_flags_12.engineering_horology_water_clock] =               "Engineering, Horology, Water clock",
           [df.knowledge_scholar_flags_12.engineering_horology_conical_water_clock] =       "Engineering, Horology, Conical water clock",
           [df.knowledge_scholar_flags_12.engineering_horology_water_clock_reservoir] =     "Engineering, Horology, Water clock reservoir",
           [df.knowledge_scholar_flags_12.engineering_horology_astrarium] =                 "Engineering, Horology, Astrarium",
           [df.knowledge_scholar_flags_12.engineering_horology_hourglass] =                 "Engineering, Horology, Hourglass",
           [df.knowledge_scholar_flags_12.engineering_horology_mechanical_clock] =          "Engineering, Horology, Mechanical Clock",
           [df.knowledge_scholar_flags_12.engineering_machine_theory_of_pulley] =           "Engineering, Machine, Theory of pulley",
           [df.knowledge_scholar_flags_12.engineering_machine_pulley] =                     "Engineering, Machine, Pulley",
           [df.knowledge_scholar_flags_12.engineering_machine_theory_of_screw] =            "Engineering, Machine, Theory of screw",
           [df.knowledge_scholar_flags_12.engineering_machine_screw] =                      "Engineering, Machine, Screw",
           [df.knowledge_scholar_flags_12.engineering_machine_theory_of_wheel_and_axle] =   "Engineering, Machine, Theory of wheel and axle",
           [df.knowledge_scholar_flags_12.engineering_machine_windlass] =                   "Engineering, Machine, Windlass",
           [df.knowledge_scholar_flags_12.engineering_machine_theory_of_wedge] =            "Engineering, Machine, Theory of wedge",
           [df.knowledge_scholar_flags_12.engineering_machine_theory_of_lever] =            "Engineering, Machine, Theory of lever",
           [df.knowledge_scholar_flags_12.engineering_machine_lever] =                      "Engineering, Machine, Lever",
           [df.knowledge_scholar_flags_12.engineering_machine_straight_beam_balance] =      "Engineering, Machine, Straight beam balance",
           [df.knowledge_scholar_flags_12.engineering_machine_theory_of_gears] =            "Engineering, Machine, Theory of gears",
           [df.knowledge_scholar_flags_12.engineering_machine_warded_lock] =                "Engineering, Machine, Warded lock",
           [df.knowledge_scholar_flags_12.engineering_machine_tumbler_lock] =               "Engineering, Machine, Tumbler lock",
           [df.knowledge_scholar_flags_12.engineering_machine_padlock] =                    "Engineering, Machine, Padlock",
           [df.knowledge_scholar_flags_12.engineering_machine_camshaft] =                   "Engineering, Machine, Camshaft",
           [df.knowledge_scholar_flags_12.engineering_machine_crankshaft] =                 "Engineering, Machine, Crankshaft",
           [df.knowledge_scholar_flags_12.engineering_machine_water_powered_sawmill] =      "Engineering, Machine, Water powered sawmill",
           [df.knowledge_scholar_flags_12.engineering_machine_chariot_odometer] =           "Engineering, Machine, Chariot odometer",
           [df.knowledge_scholar_flags_12.engineering_machine_chain_drive] =                "Engineering, Machine, Chain drive",
           [df.knowledge_scholar_flags_12.engineering_machine_mechanical_compass] =         "Engineering, Machine, Mechanical compass",
           [df.knowledge_scholar_flags_12.engineering_machine_differential_gear] =          "Engineering, Machine, Differential gear",
           [df.knowledge_scholar_flags_12.engineering_machine_combination_lock] =           "Engineering, Machine, Combination lock",
           [df.knowledge_scholar_flags_12.engineering_machine_verge_escapement] =           "Engineering, Machine, Verge escapement",
           [df.knowledge_scholar_flags_12.engineering_machine_balance_wheel] =              "Engineering, Machine, Balance wheel",
           [df.knowledge_scholar_flags_12.engineering_fluid_theory_of_siphon] =             "Engineering, Fluid, Theory of siphon"},
   [13] = {[df.knowledge_scholar_flags_13.engineering_fluid_valves] =                       "Engineering, Fluid, Valves",
           [df.knowledge_scholar_flags_13.engineering_fluid_force_pump] =                   "Engineering, Fluid, Force pump",
           [df.knowledge_scholar_flags_13.engineering_optics_crystal_lens] =                "Engineering, Optics, Crystal lens",
           [df.knowledge_scholar_flags_13.engineering_optics_water_filled_spheres] =        "Engineering, Optics, Water filled spheres",
           [df.knowledge_scholar_flags_13.engineering_optics_glass_lens] =                  "Engineering, Optics, Glass lens",
           [df.knowledge_scholar_flags_13.engineering_optics_camera_obscura] =              "Engineering, Optics, Camera obscura",
           [df.knowledge_scholar_flags_13.engineering_optics_parabolic_mirror] =            "Engineering, Optics, Parabolic mirror",
           [df.knowledge_scholar_flags_13.engineering_optics_theory_of_color] =             "Engineering, Optics, Theory of color",
           [df.knowledge_scholar_flags_13.engineering_optics_theory_of_rainbows] =          "Engineering, Optics, Theory of rainbows",
           [df.knowledge_scholar_flags_13.engineering_optics_law_of_refraction] =           "Engineering, Optics, Law of refraction",
           [df.knowledge_scholar_flags_13.engineering_design_models_and_templates] =        "Engineering, Design, Models and templates",
           [df.knowledge_scholar_flags_13.engineering_construction_wood_lamination] =       "Engineering, Construction, Wood lamination",
           [df.knowledge_scholar_flags_13.engineering_astronomy_dioptra] =                  "Engineering, Astronomy, Dioptra",
           [df.knowledge_scholar_flags_13.engineering_astronomy_astrolabe] =                "Engineering, Astronomy, Astrolabe",
           [df.knowledge_scholar_flags_13.engineering_astronomy_armillary_sphere] =         "Engineering, Astronomy, Armillary sphere",
           [df.knowledge_scholar_flags_13.engineering_astronomy_spherical_astrolabe] =      "Engineering, Astronomy, Spherical astrolabe",
           [df.knowledge_scholar_flags_13.engineering_astronomy_mural_instrument] =         "Engineering, Astronomy, Mural instrument",
           [df.knowledge_scholar_flags_13.engineering_astronomy_orrery] =                   "Engineering, Astronomy, Orrery",
           [df.knowledge_scholar_flags_13.engineering_machine_water_powered_trip_hammer] =  "Engineering, Machine, Water powered trip hammer",
           [df.knowledge_scholar_flags_13.engineering_machine_double_acting_piston_bellows] = "Engineering, Machine, Double acting piston bellows",
           [df.knowledge_scholar_flags_13.engineering_fluid_archimedes_principle] =         "Engineering, Fluid, Archimedes principle",
           [df.knowledge_scholar_flags_13.engineering_optics_atmospheric_refraction] =      "Engineering, Optics, Atmospheric refraction",
           [df.knowledge_scholar_flags_13.engineering_optics_cause_of_twilight] =           "Engineering, Optics, Cause of twilight",
           [df.knowledge_scholar_flags_13.engineering_optics_height_of_atmosphere] =        "Engineering, Optics, Height of atmosphere",
           [df.knowledge_scholar_flags_13.engineering_machine_piston] =                     "Engineering, Machine, Piston",
           [df.knowledge_scholar_flags_13.engineering_machine_crank] =                      "Engineering, Machine, Crank",
           [df.knowledge_scholar_flags_13.engineering_machine_bellows] =                    "Engineering, Machine, Bellows",
           [df.knowledge_scholar_flags_13.engineering_machine_water_powered_piston_bellows] = "Engineering, Machine, Water powered piston bellows",
           [df.knowledge_scholar_flags_13.engineering_machine_water_wheel] =                "Engineering, Machine, Water wheel",
           [df.knowledge_scholar_flags_13.engineering_machine_trip_hammer] =                "Engineering, Machine, Trip hammer"}}
   
--=====================================

function Librarian ()
  if not dfhack.isMapLoaded () then
    dfhack.printerr ("Error: This script requires a Fortress Mode embark to be loaded.")
    return
  end
  
  local Focus = "Main"
  local Pre_Help_Focus = "Main"
  local Pre_Hiding_Focus = "Main"
  local Main_Page = {}
  local Science_Page = {}
  local Values_Page = {}
  local Authors_Page = {}
  local Interactions_Page = {}
  local Hidden_Page = {}
  local Help_Page = {}
  local persist_screen
  local civ_id = df.global.world.world_data.active_site [0].entity_links [0].entity_id
  
  local keybindings = {
    content_type = {key = "CUSTOM_C",
                    desc = "Set Content Type filter"},
    reference_filter = {key = "CUSTOM_R",
                        desc = "Toggle Reference Filter"},
    main = {key = "CUSTOM_M",
            desc = "Shift to the Main page"},
    science = {key = "CUSTOM_S",
               desc = "Shift to the Science page"},
    values = {key = "CUSTOM_V",
              desc = "Shift to the Values page"},
    authors = {key = "CUSTOM_A",
               desc = "Shift to the Authors page"},
    interactions = {key = "CUSTOM_I",
                    desc = "Shift to the Interactions page"},
    forbid_book = {key = "CUSTOM_F",
                   desc = "Toggle 'f'orbidden flag on selected book"},
    dump_book = {key = "CUSTOM_D",
                 desc = "Toggle 'd'ump flag on selected book"},
    trader_book = {key = "CUSTOM_T",
                   desc = "Toggle 't'rader flag on selected book"},
    zoom = {key = "CUSTOM_Z",
            desc = "Zoom to a book"},
    ook = {key = "CUSTOM_SHIFT_O",
           desc = "Bring the Librarian out of hiding"},
    left = {key = "CURSOR_LEFT",
            desc = "Rotates to the next list"},
    right = {key = "CURSOR_RIGHT",
             desc = "Rotates to the previous list"},
    help = {key = "HELP",
            desc= "Show this help/info"}}
            
  local Content_Type_Selected = 1
  local Reference_Filter = false
  local Content_Type_Map = {}
  local ook_key_string = dfhack.screen.getKeyDisplay (df.interface_key [keybindings.ook.key])

 --============================================================

  function Sort (list)
    local temp
    
    for i, dummy in ipairs (list) do
      for k = i + 1, #list do
        if df.written_content.find (list [k] [1]).title < df.written_content.find (list [i] [1]).title then
          temp = list [i]
          list [i] = list [k]
          list [k] = temp          
        end
      end
    end
  end
  
  --============================================================

  function Sort_Remote (list, list_map)
    local temp
    local map_temp
    
    for i, dummy in ipairs (list) do
      for k = i + 1, #list do
        if list [k] < list [i] then
          temp = list [i]
          list [i] = list [k]
          list [k] = temp
          map_temp = list_map [i]
          list_map [i] = list_map [k]
          list_map [k] = map_temp
        end
      end
    end
  end
  
  --============================================================

  function Fit (Item, Size)
    return Item .. string.rep (' ', Size - string.len (Item))
  end
   
  --============================================================

  function Fit_Right (Item, Size)
    if string.len (Item) > Size then
      return string.rep ('#', Size)
    else
      return string.rep (' ', Size - string.len (Item)) .. Item
    end
  end

  --============================================================

  function Bool_To_YN (value)
    if value then
      return 'Y'
    else
      return 'N'
    end
  end
  
  --============================================================

  function Bool_To_Yes_No (value)
    if value then
      return 'Yes'
    else
      return 'No'
    end
  end
  
  --============================================================

  function check_flag (flag, index)
    return df [flag] [index] ~= nil
  end
  
  --============================================================

  function flag_image (flag, index)
    return df [flag] [index]
  end
  
  --============================================================

  function Make_List (List)
    local Result = {}
    
    for i, element in ipairs (List) do
      table.insert (Result, element.name)
    end
     
    return Result
  end
  
  --============================================================

  function value_strengh_of (ref_level)
    local strength
    local level
    
    if ref_level < -40 then
      strength = -3
      level = "Hate"
            
    elseif ref_level < -25 then
      strength = -2
      level = "Strong dislike"
                
    elseif ref_level < -10 then
      strength = -1
      level = "Dislike"
        
    elseif ref_level <= 10 then
      strength = 0
      level = "Indifference"
          
    elseif ref_level <= 25 then
      strength = 1
      level = "Like"
          
    elseif ref_level <= 40 then
      strength = 2
      level = "Strong liking"
          
    else
      strength = 3
      level = "Love"
    end
    
    return strength, level
  end
            
  --============================================================

  function Process_Item (Result, item)
    local found
    
    if item.pos.x == -30000 or
       item.pos.y == -30000 or
       item.pos.z == -30000 then
      return  --  Filter visitor owned and carried items.
    end
    
    for i, improvement in ipairs (item.improvements) do
      if improvement._type == df.itemimprovement_pagesst or
         improvement._type == df.itemimprovement_writingst then
        for k, content_id in ipairs (improvement.contents) do
          found = false
            
          for l, existing_content in ipairs (Result) do
            if existing_content [1] == content_id then
              found = true
              table.insert (Result [l] [2], item)
              break
            end
          end
          
          if not found then
            table.insert (Result, {content_id, {}})
            table.insert (Result [#Result] [2], item)
          end
        end
      end
    end
  end
  
  --============================================================

  function Take_Stock ()
    local Result = {}
    
    for i, item in ipairs (df.global.world.items.other.BOOK) do
      Process_Item (Result, item)
    end
    
    for i, item in ipairs (df.global.world.items.other.TOOL) do
      Process_Item (Result, item)
    end
    
    Sort (Result)
    
    return Result
  end
  
  --============================================================

  function Take_Science_Stock (Stock)
    local Result = {}
    
    for i = 0, 13 do  --  No content type enum known...
      Result [i] = {}
    end
    
    for i, element in ipairs (Stock) do
      local content = df.written_content.find (element [1])
      
      for k, ref in ipairs (content.refs) do
        if ref._type == df.general_ref_knowledge_scholar_flagst then 
          for l, flag in ipairs (ref.knowledge.flag_data.flags_0) do  --  Don't care which one, as they'll iterate of all bits regardless
            if flag then
              if not Result [ref.knowledge.flag_type] [l] then
                Result [ref.knowledge.flag_type] [l] = {}
              end
                
              table.insert (Result [ref.knowledge.flag_type] [l], element)
            end
          end
        end
      end
    end
    
    return Result
  end
  
  --============================================================

  function Take_Values_Stock (Stock)
    local Result = {}
    
    for i, value in ipairs (df.value_type) do
      Result [i] = {}
    end
    
    for i, element in ipairs (Stock) do
      local content = df.written_content.find (element [1])
      
      for k, ref in ipairs (content.refs) do
        if ref._type == df.general_ref_value_levelst then 
          local strength, level = value_strengh_of (ref.level)           

          if not Result [ref.value] [strength] then
            Result [ref.value] [strength] = {}
          end
                
          table.insert (Result [ref.value] [strength], element)
        end
      end
    end
    
    return Result
  end
  
  --============================================================

  function Take_Authors_Stock (Stock)
    local Result = {}
    
    for i, element in ipairs (Stock) do
      local content = df.written_content.find (element [1])
      local hf = df.historical_figure.find (content.author)
      
      if hf then
        local unit = df.unit.find (hf.unit_id)
         
        if unit and
           unit.civ_id == civ_id and
           not unit.flags2.visitor then
          local author = dfhack.TranslateName (hf.name, true) .. "/" .. dfhack.TranslateName (hf.name, false)
          local found = false

          for k, res in ipairs (Result) do
            if res [1] == author then
              found = true
              table.insert (Result [k] [2], element)
              break
            end
          end
          
          if not found then
            table.insert (Result, {author, {element}})
          end
        end
      end
    end
    
    local temp
    
    for i, dummy in ipairs (Result) do
      for k = i + 1, #Result do
        if Result [k] [1] < Result [i] [1] then
          temp = Result [i]
          Result [i] = Result [k]
          Result [k] = temp          
        end
      end
    end
          
    return Result
  end
  
  --============================================================

  function Take_Interactions_Stock (Stock)
    local Result = {}
    
    for i, element in ipairs (Stock) do
      local content = df.written_content.find (element [1])
      
      for k, ref in ipairs (content.refs) do
        if ref._type == df.general_ref_interactionst then 
          local resolved = false
        
          for i, str in ipairs (df.global.world.raws.interactions [ref.interaction_id].str) do
            if str.value:find ("IS_NAME:", 1) ~= nil then
              table.insert (Result, {str.value:sub (str.value:find (":", 1) + 1, str.value:len () - 1), element})
              resolved = true
              break
            end
          end
        
          if not resolved then
            table.insert (Result, {"unresolved Interaction information", element})
          end
        end
      end
    end
   
    return Result
  end

  --============================================================

  function Take_Remote_Stock ()
    local Science_Result = {}
    local Values_Result = {}
    
    for i = 0, 13 do  --  No content type enum known...
      Science_Result [i] = {}
    end
    
    for i, value in ipairs (df.value_type) do
      Values_Result [i] = {}
    end
    
    for i, content in ipairs (df.global.world.written_contents.all) do
      for k, ref in ipairs (content.refs) do
        if ref._type == df.general_ref_knowledge_scholar_flagst then 
          for l, flag in ipairs (ref.knowledge.flag_data.flags_0) do  --  Don't care which one, as they'll iterate of all bits regardless
            if flag then
              local found = false
             
              if Science_Page.Data_Matrix [ref.knowledge.flag_type] [l] then
                for m, element in ipairs (Science_Page.Data_Matrix [ref.knowledge.flag_type] [l]) do
                  if element [1] == content.id then
                    found = true
                    break
                  end
                end
              end
              
              if not found then
                if not Science_Result [ref.knowledge.flag_type] [l] then
                  Science_Result [ref.knowledge.flag_type] [l] = {}
                end
                
                table.insert (Science_Result [ref.knowledge.flag_type] [l], content)
              end
            end
          end
          
        elseif ref._type == df.general_ref_value_levelst then
          local strength, level = value_strengh_of (ref.level)
          local found = false
            
          if Values_Page.Data_Matrix [ref.value] [strength] then
            for m, element in ipairs (Values_Page.Data_Matrix [ref.value] [strength]) do
              if element [1] == content.id then
                found = true
                break
              end
            end
          end
              
          if not found then
            if not Values_Result [ref.value] [strength] then
              Values_Result [ref.value] [strength] = {}
            end
                
            table.insert (Values_Result [ref.value] [strength], content)
          end            
        end
      end
    end

    Science_Page.Remote_Data_Matrix = Science_Result
    Values_Page.Remote_Data_Matrix = Values_Result
  end
  
  --============================================================

  function Filter_Stock (Stock, Content_Type_Selected, Reference_Filter)
    local include
    local Result = {}
    
    for i, element in ipairs (Stock) do
      local content = df.written_content.find (element [1])
      
      if Content_Type_Selected == 1 or
         content.type == Content_Type_Selected - 2 then
        include = not Reference_Filter
        
        if Reference_Filter then
          include = #content.refs ~= 0
        end
        
        if include then
          if content.title == "" then
            table.insert (Result, {name =" <Untitled>", element = element})
          
          else
            table.insert (Result, {name = content.title, element = element})
          end
        end
      end
    end    
    
    return Result
  end
  
  --============================================================

  function HF_Name_Of (Id)
    local hf = df.historical_figure.find (Id)
    
    if hf then
      return dfhack.TranslateName (hf.name, true) .. "/" .. dfhack.TranslateName (hf.name, false)
      
    else
      return "<Unknown histfig>"
    end
  end
  
  --============================================================
  
  function Entity_Name_Of (Id)
    local entity = df.historical_entity.find (Id)
      
    if entity then
      return dfhack.TranslateName (entity.name, true)-- .. "/" ..
             --dfhack.TranslateName (entity.name, false)
             
    else
      return "<Unknown entity>"
    end
  end
  
  --============================================================

  function Site_Name_Of (Id)
    local site = df.world_site.find (Id)
      
    if site then
      return dfhack.TranslateName (site.name, true) .. "/" ..
             dfhack.TranslateName (site.name, false)
             
    else
      return "<Unknown site>"
    end
  end
  
  --============================================================

  function Site_Info_Of (Id)
    local site = df.world_site.find (Id)
    
    if site then
      return df.world_site_type [site.type] .. " " ..
             dfhack.TranslateName (site.name, true) .. "/" ..
             dfhack.TranslateName (site.name, false)
             
    else
      return "<Unknown site>"
    end
  end
  
  --============================================================
  
  function Region_Name_Of (Id)
    local region = df.world_region.find (Id)
      
    if region then
      return dfhack.TranslateName (region.name, true) .. "/" ..
             dfhack.TranslateName (region.name, false)
             
    else
      return "<Unknown region>"
    end
  end
  
  --============================================================
  
  function Layer_Name_Of (Id)
    local region = df.world_underground_region.find (Id)
      
    if region then
      return dfhack.TranslateName (region.name, true) .. "/" ..
             dfhack.TranslateName (region.name, false)
             
    else
      return "<Unknown underground region>"
    end
  end
  
  --============================================================
  
  function History_Location_Name_Of (Site_Id, Region_Id, Layer_Id)
    if Site_Id ~= -1 then
      return Site_Name_Of (Site_Id)
      
    elseif Region_Id ~= -1 then
      return Region_Name_Of (Region_Id)
      
    elseif Layer_Id ~= -1 then
      return Layer_Name_Of (Layer_Id)
    else
      return "<Unknown location>"
    end
  end

  --============================================================

  function wrap (str)
    local screen_width, screen_height = dfhack.screen.getWindowSize ()
    local indent = 11
    local length = screen_width - 54 - 1
    local rem = str
    local first = true
    local result = ""
    
    while true do
      if first then
        if string.len (rem) <= length + 1 then  --  + 1 as the newline at the end doesn't count
          result = rem
          break
          
        else
          result = string.sub (rem, 1, length) .. "\n"
          rem = string.sub (rem, length + 1, string.len (rem))
          first = false
        end
              
      else
        if string.len (rem) <= length - indent + 1 then  --  + 1 as the newline at the end doesn't count
           result = result .. string.rep (" ", indent) .. rem
           break
           
        else
          result = result .. string.rep (" ", indent) .. string.sub (rem, 1, length - indent)
          rem = string.sub (rem, length - indent + 1, string.len (rem))
        end
      end
    end
    
    return result
  end
  
  --============================================================

  function Produce_Details (element)
    if not element then
      return ""
    end
    
    local content = df.written_content.find (element [1])
    
    if not content then
      return ""
    end
    
    local title = content.title
    local copies = 0
    local original = false
    
    if title == "" then
      title = "<Untitled>"
    end

    local text = {wrap ("Title    : " .. title .. "\n"),
                  wrap ("Category : " .. df.written_content_type [content.type] .. "\n")}
                  
    
    for i, ref in ipairs (content.refs) do
      if ref._type == df.general_ref_artifact or
         ref._type == df.general_ref_nemesis or
         ref._type == df.general_ref_item or
         ref._type == df.general_ref_item_type or
         ref._type == df.general_ref_coinbatch or
         ref._type == df.general_ref_mapsquare or
         ref._type == df.general_ref_entity_art_image or
         ref._type == df.general_ref_projectile or
         ref._type == df.general_ref_unit or
         ref._type == df.general_ref_building or
         --  ref._type == df.general_ref_entity or
         ref._type == df.general_ref_locationst or
         --  ref._type == df.general_ref_interactionst or
         ref._type == df.general_ref_abstract_buildingst or
         --  ref._type == df.general_ref_historical_eventst or
         ref._type == df.general_ref_spherest or
         --  ref._type == df.general_ref_sitest or
         ref._type == df.general_ref_subregionst or
         ref._type == df.general_ref_feature_layerst or
         --  ref._type == df.general_ref_historical_figurest or
         ref._type == df.general_ref_entity_popst or
         ref._type == df.general_ref_creaturest or
         --  ref._type == df.general_ref_knowledge_scholar_flagst or
         ref._type == df.general_ref_activity_eventst then
         --  ref._type == df.general_ref_value_levelst or
         --  ref._type == df.general_ref_languagest or
         --  ref._type == df.general_ref_written_contentst or
         --  ref._type == df.general_ref_poetic_formst or
         --  ref._type == df.general_ref_musical_formst or
         --  ref._type == df.general_ref_dance_formst then
        table.insert (text, wrap ("Reference: Unresolved " .. tostring (ref._type) .. " information\n"))
        
      elseif ref._type == df.general_ref_entity then
        local entity = df.historical_entity.find (ref.entity_id)
        local race
        local name
        
        if entity.race == -1 then
          race = "<unknown race>"
          
        else
          race = df.global.world.raws.creatures.all [entity.race].name [2]
        end
          
        if entity.name then
          name = dfhack.TranslateName (entity.name, true) .. "/" .. dfhack.TranslateName (entity.name, false)
          
        else
          name "<unknown name>"
        end
        
        if entity then
          table.insert (text, wrap ("Reference: The " ..  race .. " " ..
                                    df.historical_entity_type [entity.type] .. " " .. name .. " information\n"))
            
        else
          table.insert (text, wrap ("Reference: Unknown entity (culled?) information\n"))
        end
       
      elseif ref._type == df.general_ref_interactionst then       
        local resolved = false
        
        for i, str in ipairs (df.global.world.raws.interactions [ref.interaction_id].str) do
          if str.value:find ("IS_NAME:", 1) ~= nil then
            table.insert (text, wrap ('Interaction reference: "' .. str.value:sub (str.value:find (":", 1) + 1, str.value:len () - 1) .. '"\n'))
            resolved = true
            break
          end
        end
        
        if not resolved then
          table.insert (text, wrap ("Reference: unresolved Interaction information\n"))
        end
        
      elseif ref._type == df.general_ref_historical_eventst then
        local event = df.history_event.find (ref.event_id)
          
        if event then      
          if event._type == df.history_event_war_attacked_sitest or
             event._type == df.history_event_war_destroyed_sitest or
             --  event._type == df.history_event_created_sitest or
             event._type == df.history_event_hist_figure_diedst or
             --  event._type == df.history_event_add_hf_entity_linkst or            
             event._type == df.history_event_remove_hf_entity_linkst or            
             event._type == df.history_event_first_contactst or            
             event._type == df.history_event_first_contact_failedst or            
             event._type == df.history_event_topicagreement_concludedst or            
             event._type == df.history_event_topicagreement_rejectedst or            
             event._type == df.history_event_topicagreement_madest or            
             --  event._type == df.history_event_war_peace_acceptedst or            
             --  event._type == df.history_event_war_peace_rejectedst or            
             event._type == df.history_event_diplomat_lostst or            
             event._type == df.history_event_agreements_voidedst or            
             event._type == df.history_event_merchantst or            
             event._type == df.history_event_artifact_hiddenst or            
             event._type == df.history_event_artifact_possessedst or            
             event._type == df.history_event_artifact_createdst or            
             event._type == df.history_event_artifact_lostst or            
             event._type == df.history_event_artifact_foundst or            
             event._type == df.history_event_artifact_recoveredst or            
             event._type == df.history_event_artifact_droppedst or            
             event._type == df.history_event_reclaim_sitest or            
             --  event._type == df.history_event_hf_destroyed_sitest or            
             event._type == df.history_event_site_diedst or            
             event._type == df.history_event_site_retiredst or            
             event._type == df.history_event_entity_createdst or            
             event._type == df.history_event_entity_actionst or            
             event._type == df.history_event_entity_incorporatedst or            
             --  event._type == df.history_event_created_buildingst or            
             event._type == df.history_event_replaced_buildingst or            
             event._type == df.history_event_add_hf_site_linkst or            
             event._type == df.history_event_remove_hf_site_linkst or            
             --  event._type == df.history_event_add_hf_hf_linkst or            
             event._type == df.history_event_remove_hf_hf_linkst or            
             event._type == df.history_event_entity_razed_buildingst or            
             event._type == df.history_event_masterpiece_createdst or            
             event._type == df.history_event_masterpiece_created_arch_designst or            
             event._type == df.history_event_masterpiece_created_arch_constructst or            
             event._type == df.history_event_masterpiece_created_itemst or            
             event._type == df.history_event_masterpiece_created_dye_itemst or            
             event._type == df.history_event_masterpiece_created_item_improvementst or            
             event._type == df.history_event_masterpiece_created_foodst or            
             event._type == df.history_event_masterpiece_created_engravingst or            
             event._type == df.history_event_masterpiece_lostst or            
             --  event._type == df.history_event_change_hf_statest or            
             --  event._type == df.history_event_change_hf_jobst or            
             event._type == df.history_event_war_field_battlest or            
             --  event._type == df.history_event_war_plundered_sitest or            
             event._type == df.history_event_war_site_new_leaderst or            
             event._type == df.history_event_war_site_tribute_forcedst or            
             event._type == df.history_event_war_site_taken_overst or            
             event._type == df.history_event_body_abusedst or            
             event._type == df.history_event_hist_figure_abductedst or            
             event._type == df.history_event_item_stolenst or            
             event._type == df.history_event_hf_razed_buildingst or            
             --  event._type == df.history_event_creature_devouredst or            
             event._type == df.history_event_hist_figure_woundedst or            
             event._type == df.history_event_hist_figure_simple_battle_eventst or            
             event._type == df.history_event_created_world_constructionst or            
             event._type == df.history_event_hist_figure_reunionst or            
             event._type == df.history_event_hist_figure_reach_summitst or            
             event._type == df.history_event_hist_figure_travelst or            
             event._type == df.history_event_hist_figure_new_petst or            
             event._type == df.history_event_assume_identityst or            
             event._type == df.history_event_create_entity_positionst or            
             event._type == df.history_event_change_creature_typest or            
             event._type == df.history_event_hist_figure_revivedst or            
             event._type == df.history_event_hf_learns_secretst or            
             event._type == df.history_event_change_hf_body_statest or            
             event._type == df.history_event_hf_act_on_buildingst or            
             event._type == df.history_event_hf_does_interactionst or            
             event._type == df.history_event_hf_confrontedst or            
             event._type == df.history_event_entity_lawst or            
             event._type == df.history_event_hf_gains_secret_goalst or            
             event._type == df.history_event_artifact_storedst or            
             event._type == df.history_event_agreement_formedst or            
             event._type == df.history_event_site_disputest or            
             event._type == df.history_event_agreement_concludedst or            
             event._type == df.history_event_insurrection_startedst or            
             event._type == df.history_event_insurrection_endedst or            
             event._type == df.history_event_hf_attacked_sitest or            
             event._type == df.history_event_performancest or            
             --  event._type == df.history_event_competitionst or            
             event._type == df.history_event_processionst or            
             event._type == df.history_event_ceremonyst or            
             event._type == df.history_event_knowledge_discoveredst or            
             event._type == df.history_event_artifact_transformedst or            
             event._type == df.history_event_artifact_destroyedst or            
             --  event._type == df.history_event_hf_relationship_deniedst or            
             event._type == df.history_event_regionpop_incorporated_into_entityst or            
             event._type == df.history_event_poetic_form_createdst or            
             event._type == df.history_event_musical_form_createdst or            
             event._type == df.history_event_dance_form_createdst or            
             --  event._type == df.history_event_written_content_composedst or            
             event._type == df.history_event_change_hf_moodst or            
             event._type == df.history_event_artifact_claim_formedst or            
             event._type == df.history_event_artifact_givenst or            
             event._type == df.history_event_hf_act_on_artifactst or            
             event._type == df.history_event_hf_recruited_unit_type_for_entityst or            
             event._type == df.history_event_hfs_formed_reputation_relationshipst or            
             event._type == df.history_event_artifact_copiedst or            
             event._type == df.history_event_sneak_into_sitest or            
             event._type == df.history_event_spotted_leaving_sitest or            
             event._type == df.history_event_entity_searched_sitest or            
             event._type == df.history_event_hf_freedst or            
             event._type == df.history_event_hist_figure_simple_actionst or            
             event._type == df.history_event_entity_rampaged_in_sitest or            
             event._type == df.history_event_entity_fled_sitest or            
             event._type == df.history_event_tactical_situationst or            
             event._type == df.history_event_squad_vs_squadst then            
            table.insert (text, wrap ("Reference: Unsupported " .. tostring (event._type) .. " historical event information\n"))

          elseif event._type == df.history_event_created_sitest then
            table.insert (text, wrap ("Reference: " .. Entity_Name_Of (event.civ) .. " local government " ..
                                      Entity_Name_Of (event.site_civ) .. " founded " ..
                                      Site_Name_Of (event.site) .. " led by " ..
                                      HF_Name_Of (event.builder_hf) .. "\n"))
            
          elseif event._type == df.history_event_add_hf_entity_linkst then
            local position = ""
            local entity = df.historical_entity.find (event.civ)

            if event.position_id ~= -1 and
               entity and
               #entity.positions.own > event.position_id then  --  ### Had a case of a reference to index 2 on a vector length 2, with next index being 3...
              position = " as " .. entity.positions.own [event.position_id].name [0]
            end
              
            table.insert (text, wrap ("Reference: " .. HF_Name_Of (event.histfig) .. " " ..
                                      df.histfig_entity_link_type [event.link_type] .. " " ..
                                      Entity_Name_Of (event.civ) .. position .. "\n"))
            
          elseif event._type == df.history_event_created_buildingst then
            table.insert (text, wrap ("Reference: " .. Entity_Name_Of (event.civ) .. " created " ..
                                      df.abstract_building_type [event.structure] .. " in " ..  --### May be reference to buildings at site instead...
                                      Site_Name_Of (event.site) .. " by " ..
                                      HF_Name_Of (event.builder_hf) .. "\n"))
            
          elseif event._type == df.history_event_war_peace_acceptedst then
            table.insert (text, wrap ("Reference: " .. Entity_Name_Of (event.source) .. " " ..
                                      df.meeting_topic [event.topic] .. " with " ..
                                      Entity_Name_Of (event.destination) .. " at " ..
                                      Site_Name_Of (event.site) .. " accepted\n"))
          
          elseif event._type == df.history_event_war_peace_rejectedst then
            table.insert (text, wrap ("Reference: " .. Entity_Name_Of (event.source) .. " " ..
                                      df.meeting_topic [event.topic] .. " with " ..
                                      Entity_Name_Of (event.destination) .. " at " ..
                                      Site_Name_Of (event.site) .. " rejected\n"))
            
          elseif event._type == df.history_event_hf_destroyed_sitest then
            table.insert (text, wrap ("Reference: " .. HF_Name_Of (event.attacker_hf) .. " destroyed " ..
                                      Site_Name_Of (event.site) .. " governed by\n           " ..
                                      Entity_Name_Of (event.site_civ) .. " belonging to " ..
                                      Entity_Name_Of (event.defender_civ) .. "\n"))
          
          elseif event._type == df.history_event_add_hf_hf_linkst then
            table.insert (text, wrap ("Reference: Added " .. HF_Name_Of (event.hf) .. " " .. df.histfig_hf_link_type [event.type] .. 
                                      " vs " .. HF_Name_Of (event.hf_target) .. "\n"))
              
          elseif event._type == df.history_event_change_hf_statest then
            local state = " <Unknown state>"
              
            if event.state == 0 then
              state = " wandered in"
                
            elseif event.state == 1 then
              state = " settled in"
                
            elseif event.state == 2 then
              state = " Became refugee from"
                
            elseif event.state == 5 then
              state = " visited"
            end
              
            table.insert (text, wrap ("Reference: " .. HF_Name_Of (event.hfid) .. state .. " " ..
                                      History_Location_Name_Of (event.site, event.region, event.layer) .. 
                                      " because of " .. df.history_event_reason [event.reason] .. "\n"))
              
          elseif event._type == df.history_event_change_hf_jobst then
            table.insert (text, wrap ("Reference: " .. HF_Name_Of (event.hfid) .. " changed job from " .. df.profession [event.old_job] .. " to " .. 
                                      df.profession [event.new_job] .. " in " .. History_Location_Name_Of (event.site, event.region, event.layer) .. "\n"))
              
          elseif event._type == df.history_event_war_plundered_sitest then
            table.insert (text, wrap ("Reference: " .. Entity_Name_Of (event.attacker_civ) .. " attacked " ..
                                      Entity_Name_Of (event.defender_civ) .. " and plundered " ..
                                      Site_Name_Of (event.site) .. " under the control of " ..
                                      Entity_Name_Of (event.site_civ) .. "\n"))
                                
          elseif event._type == df.history_event_creature_devouredst then
            --### caste
            table.insert (text, wrap ("Reference: The " .. df.global.world.raws.creatures.all [event.race].name [0] .. " " ..
                                      HF_Name_Of (event.victim) .. " was devoured by " ..
                                      HF_Name_Of (event.eater) .. " " ..
                                      Entity_Name_Of (event.entity) .. " " ..
                                      History_Location_Name_Of (event.site, event.region, event.layer) .. "\n"))
                                
          elseif event._type == df.history_event_competitionst then
            local schedule = df.global.world.entities.all [event.entity].occasion_info.occasions [event.occasion].schedule [event.schedule]
            local competition_text = ""
            
            if schedule.type == df.occasion_schedule_type.DANCE_COMPETITION then
              if schedule.reference ~= -1 then
                competition_text = "Dance Competition using the " .. dfhack.TranslateName (df.global.world.dance_forms.all [schedule.reference].name, true) .. " dance form"
                
              else
                competition_text = "Dance Competition"
              end
              
            elseif schedule.type == df.occasion_schedule_type.MUSICAL_COMPETITION then
              if schedule.reference ~= -1 then
                competition_text = "Musical Competition using the " .. dfhack.TranslateName (df.global.world.musical_forms.all [schedule.reference].name, true) .. " musical form"
                
              else
                competition_text = "Musical Competition"
              end
              
            elseif schedule.type == df.occasion_schedule_type.POETRY_COMPETITION then
              if schedule.reference ~= -1 then
                competition_text = "Poetry Competition using the " .. dfhack.TranslateName (df.global.world.poetical_forms.all [schedule.reference].name, true) .. " poetical form"
                
              else
                competition_text = "Poetry Competition"
              end
              
            elseif schedule.type == df.occasion_schedule_type.FOOT_RACE then
              competition_text = "Foot Race"
              
            elseif schedule.type == df.occasion_schedule_type.WRESTLING_COMPETITION then
              competition_text = "Wrestling Competition"
              
            elseif schedule.type == df.occasion_schedule_type.THROWING_COMPETITION then
              competition_text = dfhack.items.getSubtypeDef (schedule.reference, schedule.reference2).name .. " Throwing Competition"
              
            elseif schedule.type == df.occasion_schedule_type.GLADIATORY_COMPETITION then
              competition_text = "Gladiatorial Competition"
              
            else
              competition_text = df.occasion_schedule_type [schedule.type]
            end
                        
            table.insert (text, wrap ("Reference: " .. competition_text .. " at " .. History_Location_Name_Of (event.site, event.region, event.layer) .. "\n"))
            --### competitor_hf and winner_hf vectors
            
          elseif event._type == df.history_event_hf_relationship_deniedst then
            table.insert (text, wrap ("Reference: " .. HF_Name_Of (event.seeker_hf) .. " was denied " ..
                                      df.unit_relationship_type [event.type] .. " by " ..
                                      HF_Name_Of (event.target_hf) .. " because\n           " ..
                                      df.history_event_reason [event.reason] .. " of " ..
                                      HF_Name_Of (event.reason_id) .. " at " ..
                                      History_Location_Name_Of (event.site, event.region, event.layer) .. "\n"))
              
          elseif event._type == df.history_event_written_content_composedst then
            local content = df.written_content.find (event.content)
            local title = "<Untitled>"
              
            if content and
               content.title ~= "" then
              title = content.title
            end
            --### Circumstances
            --### Reason
            
            table.insert (text, wrap ("Reference: " .. HF_Name_Of (event.histfig) .. " wrote " .. title ..
                                      " at " .. History_Location_Name_Of (event.site, event.region, event.layer) .. "\n"))
                                
          else
            table.insert (text, wrap ("Reference: *UNKNOWN* " .. tostring (event._type) .. " historical event information\n"))
          end
            
        else
          table.insert (text, wrap ("Reference: Unknown historical event information (culled?)\n"))
        end
          
      elseif ref._type == df.general_ref_sitest then
        table.insert (text, wrap ("Reference: Information about the " .. Site_Info_Of (ref.site_id) .. "\n"))
          
      elseif ref._type == df.general_ref_historical_figurest then
        local hf = df.historical_figure.find (ref.hist_figure_id)
          
        if hf then
          table.insert (text, wrap ("Reference: Biography of the " .. df.global.world.raws.creatures.all [hf.race].name [0] ..
                                    " " .. HF_Name_Of (ref.hist_figure_id) .. "\n"))
          
        else
          table.insert (text, wrap ("Reference: Biography of unknown historical figure (culled?)\n"))
        end
          
      elseif ref._type == df.general_ref_knowledge_scholar_flagst then
        for k, flag in ipairs (ref.knowledge.flag_data.flags_0) do  --  Iterates over all 32 bits regardless of enum value existence, so which "enum" we use doesn't matter
          if flag then
            table.insert (text, wrap ("Reference: " .. knowledge [ref.knowledge.flag_type] [k] .. " knowledge\n"))
          end
        end
        
      elseif ref._type == df.general_ref_value_levelst then
        local strength, level = value_strengh_of (ref.level)
          
        table.insert (text, wrap ('Reference: Moves values towards "' .. values [ref.value] [strength] .. '" = ' .. level .. "\n"))
        
      elseif ref._type == df.general_ref_languagest then
        table.insert (text, wrap ("Reference: Dictionary of the " .. df.global.world.raws.language.translations [ref.anon_1].name .. " language\n")) --###
          
      elseif ref._type == df.general_ref_written_contentst then
        table.insert (text, wrap ("Reference: Written Contents Titled " .. df.global.world.written_contents.all [ref.written_content_id].title .. "\n"))
         
      elseif ref._type == df.general_ref_poetic_formst then
        table.insert (text, wrap ("Reference: Poetic Form " .. dfhack.TranslateName (df.global.world.poetic_forms.all [ref.poetic_form_id].name, true) .. "\n"))
      
      elseif ref._type == df.general_ref_musical_formst then
        table.insert (text, wrap ("Reference: Musical Form " .. dfhack.TranslateName (df.global.world.musical_forms.all [ref.musical_form_id].name, true) .. "\n"))
      
      elseif ref._type == df.general_ref_dance_formst then
        table.insert (text, wrap ("Reference: Dance Form " .. dfhack.TranslateName (df.global.world.dance_forms.all [ref.dance_form_id].name, true) .. "\n"))
      
      else
        table.insert (text, wrap ("Reference: *UNKNOWN* " .. tostring (ref._type) .. " information\n"))
      end
    end
    
    if element [2] then
      for i, item in ipairs (element [2]) do
        if item.flags.artifact then
          original = true
        
        else
          copies = copies + 1
        end
      end
    
      table.insert (text, wrap ("Original : " .. tostring (Bool_To_Yes_No (original) .. "\n")))
      table.insert (text, wrap ("Copies   : " .. tostring (copies) .. "\n"))
    end
    
    local hf = df.historical_figure.find (content.author)
--    local author = "<Unknown>"
    local Local = false
    
    if hf then
--      author = dfhack.TranslateName (hf.name, true) .. "/" .. dfhack.TranslateName (hf.name, false)
      local unit = df.unit.find (hf.unit_id)
      
      if unit and
         unit.civ_id == civ_id and
         not unit.flags2.visitor then
        Local = true
      end
    end
    
    table.insert (text, wrap ("Author   : " .. HF_Name_Of (content.author) .. "\n"))
    table.insert (text, wrap ("Local    : " .. tostring (Bool_To_Yes_No (Local) .. "\n")))

    return text
  end
  
  --============================================================

  function Produce_Book_List (items)
    if not items then
      return {}
    end
    
    local result = {}
    local original
    local forbidden
    local trader
    local inventory
    local dump_marked
  
    for i, item in ipairs (items) do
      if item.flags.artifact then
        original = 'O '
        
      else
        original = 'C '
      end
      
      if item.flags.forbid then
        forbidden = 'F '
        
      else
        forbidden = '  '
      end
      
      if item.flags.dump then
        dump_marked = 'D '
      
      else
        dump_marked = '  '
      end
      
      if item.flags.trader then
        trader = 'T '
      
      else
        trader = '  '
      end
      
      if item.flags.in_inventory then
        inventory = 'I '
        
      else
        inventory = '  '
      end
      
      table.insert (result, original .. forbidden .. dump_marked .. trader .. inventory)
    end
    
    return result
  end
  
  --============================================================

  function Science_Character_Of (Stock, category, index)
    if Stock [category] [index] == nil then
      return "?"
    
    else
      return "!"
    end
  end
  
  --============================================================

  function Science_Color_Of (Stock, category, index)
    if Stock [category] [index] == nil then
      return COLOR_LIGHTRED
    
    else
      return COLOR_GREEN
    end
  end
  
  --============================================================

  function Populate_Own_Remote_Science ()
    if not Science_Page.Category_List then
      return  --  Initiation. The list hasn't been defined yet.
    end
    
    local Own_List = {}
    local Remote_List = {}
    local Remote_List_Map = {}
    
    if Science_Page.Data_Matrix [Science_Page.Category_List.selected - 1] [Science_Page.Topic_List.selected - 1] then
      for i, element in ipairs (Science_Page.Data_Matrix [Science_Page.Category_List.selected - 1] [Science_Page.Topic_List.selected - 1]) do
        local content = df.written_content.find (element [1])
        local title = content.title
    
        if title == "" then
          title = "<Untitled>"
        end
      
        table.insert (Own_List, title)    
      end
    end
    
    Science_Page.Own_List:setChoices (Own_List, 1)

    if Science_Page.Remote_Data_Matrix [Science_Page.Category_List.selected - 1] [Science_Page.Topic_List.selected - 1] then
      for i, element in ipairs (Science_Page.Remote_Data_Matrix [Science_Page.Category_List.selected - 1] [Science_Page.Topic_List.selected - 1]) do
        local title = element.title
    
        if title == "" then
          title = "<Untitled>"
        end
      
        table.insert (Remote_List, title)
        table.insert (Remote_List_Map, i)
      end
    end
    
    Sort_Remote (Remote_List, Remote_List_Map)
    Science_Page.Remote_List:setChoices (Remote_List, 1)
    Science_Page.Remote_List_Map = Remote_List_Map
  end
  
  --============================================================

  function Populate_Own_Remote_Values ()
    if not Values_Page.Strength_List then
      return  --  Initiation. The list hasn't been defined yet.
    end
    
    local Own_List = {}
    local Remote_List = {}
    local Remote_List_Map = {}
    
    if Values_Page.Data_Matrix [Values_Page.Values_List.selected - 1] [Values_Page.Strength_List.selected - 4] then
      for i, element in ipairs (Values_Page.Data_Matrix [Values_Page.Values_List.selected - 1] [Values_Page.Strength_List.selected - 4]) do
        local content = df.written_content.find (element [1])
        local title = content.title
    
        if title == "" then
          title = "<Untitled>"
        end
      
        table.insert (Own_List, title)    
      end
    end
    
    Values_Page.Own_List:setChoices (Own_List)

    if Values_Page.Remote_Data_Matrix [Values_Page.Values_List.selected - 1] [Values_Page.Strength_List.selected - 4] then
      for i, element in ipairs (Values_Page.Remote_Data_Matrix [Values_Page.Values_List.selected - 1] [Values_Page.Strength_List.selected - 4]) do
        local title = element.title
    
        if title == "" then
          title = "<Untitled>"
        end
      
        table.insert (Remote_List, title)
        table.insert (Remote_List_Map, i)
      end
    end
    
    Sort_Remote (Remote_List, Remote_List_Map)
    Values_Page.Remote_List:setChoices (Remote_List, 1)
    Values_Page.Remote_List_Map = Remote_List_Map
  end
  
  --============================================================

  function Populate_Author_Works ()
    local selected = 1
    
    if Authors_Page.Authors_List then
      selected = Authors_Page.Authors_List.selected
    end
    
    local list = {}
    local list_map = {}
    
    if #Authors_Page.Authors > 0 then
      for i, element in ipairs (Authors_Page.Authors [selected] [2]) do
        local content = df.written_content.find (element [1])
        local title = content.title
    
        if title == "" then
          title = "<Untitled>"
        end
      
        table.insert (list, title)    
        table.insert (list_map, i)
      end
    end
    
    Sort_Remote (list, list_map)

    Authors_Page.Works_List:setChoices (list, 1)
    Authors_Page.Works_List_Map = list_map
  end
  
  --============================================================

  function Populate_Interactions_Works ()
    local selected = 1
    
    if Interactions_Page.Interactions_List then
      selected = Interactions_Page.Interactions_List.selected
    end
    
    local list = {}
    local list_map = {}
    
    for i, element in ipairs (Interactions_Page.Interactions) do
      local content = df.written_content.find (element [1])
      local title = content.title
    
      if title == "" then
        title = "<Untitled>"
      end
          
      table.insert (list, title .. ": " .. element [1])
      table.insert (list_map, i)
    end
    
    Sort_Remote (list, list_map)

    Interactions_Page.Works_List:setChoices (list, 1)
    Interactions_Page.Works_List_Map = list_map
  end
  
  --============================================================

  function Book_Location_And_Access_Key (item)
    local pos = {["x"] = item.pos.x,
                 ["y"] = item.pos.y,
                 ["z"] = item.pos.z}
    local key
        
    if item.flags.in_inventory then
      key = {[df.interface_key [df.interface_key.D_VIEWUNIT]] = true}
      for i, ref in ipairs (item.general_refs) do
        if ref._type == df.general_ref_unit_holderst then
          local unit = df.unit.find (ref.unit_id)
          pos.x = unit.pos.x
          pos.y = unit.pos.y
          pos.z = unit.pos.z
          return pos, key
        end
      end
        
    else
      key = {[df.interface_key [df.interface_key.D_LOOK]] = true}
          
      for i, ref in ipairs (item.general_refs) do
        if ref._type == df.general_ref_building_holderst then
          local building = df.building.find (ref.building_id)
          pos.x = building.centerx
          pos.y = building.centery
          pos.z = building.z
          key = {[df.interface_key [df.interface_key.D_BUILDITEM]] = true}
          return pos, key
          
        elseif ref._type == df.general_ref_contained_in_itemst then
          local container = df.item.find (ref.item_id)
          
          return Book_Location_And_Access_Key (container)
        end 
      end

      return pos, key        
    end
 end
  
  --============================================================

  Ui = defclass (nil, gui.FramedScreen)
  Ui.ATTRS = {
    frame_style = gui.GREY_LINE_FRAME,
    frame_title = "The Librarian",
    transparent = false
  }

  --============================================================
 
  function Ui:onRenderFrame (dc, rect)
    local x1, y1, x2, y2 = rect.x1, rect.y1, rect.x2, rect.y2

    if self.transparent then
      self:renderParent ()
      dfhack.screen.paintString (COLOR_LIGHTRED, ook_start_x, y2, ook_key_string)
      
      if dont_be_silly then
        dfhack.screen.paintString (COLOR_WHITE, ook_start_x + ook_key_string:len (), y2, ": Return to The Librarian")
      else
        dfhack.screen.paintString (COLOR_WHITE, ook_start_x + ook_key_string:len (), y2, ": Ook! Return to The Librarian")
      end
  
    else
      if rect.wgap <= 0 and rect.hgap <= 0 then
        dc:clear ()
      else
        self:renderParent ()
        dc:fill (rect, self.frame_background)
      end

      gui.paint_frame (x1, y1, x2, y2, self.frame_style, self.frame_title)
    end
  end

  --============================================================
 
  function Ui:onResize (w, h)
    self:updateLayout (gui.ViewRect {rect = gui.mkdims_wh (0, 0 , w, h)})
  end
  
  --============================================================

  function Ui:onHelp ()
    self.subviews.pages:setSelected (6)
    Pre_Help_Focus = Focus
    Focus = "Help"
  end

  --============================================================

  function Helptext_Main ()
    local helptext =
      {"Help/Info", NEWLINE,
       "The Librarian provides a few views on the literary works in your stock.", NEWLINE,
       "The help will list the main pages with their specific functions, while functionality present on all of", NEWLINE,
       "them are summarized thereafter. The pages are:", NEWLINE,
       "- The Main page contains every work in your fortress, although you can filter it on the category of the", NEWLINE,
       "  work as well as to display only works that contain references to additional information. These controls", NEWLINE,
       "  can be in effect concurrently.", NEWLINE,
       "- The Science page contains an indication of all scientific topics covered in your fortress, as well as", NEWLINE,
       "  a breakdown to actual works per scientific topic.", NEWLINE,
       "- The Values page contains an indicator of all the types of value changing works in your fortress broken", NEWLINE,
       "  down to the values in combination with the strength level target of the works. There is also a further", NEWLINE,
       "  breakdown to the actual works", NEWLINE,
       "- The Authors page contains the authors you have in your fortress and the works they have produced.", NEWLINE,
       "- The Interactions page contains the works containing interactions (Vanilla: The Secret of Life and Death)", NEWLINE,
       NEWLINE,
       "- You switch between the different pages using the appropriate command keys, listed at each page.", NEWLINE,
       "- You shift between the lists on each page using the DF left/right movement keys.", NEWLINE,
       "- All pages provide some basic details on the currently selected work. All works present in your fortress", NEWLINE,
       "  has a further list of the actual physical books (be they codices, quires, or scrolls) in your fortress", NEWLINE,
       "  showing some basic flag information on them (Original/Copy, Forbidden, Dump, Trader, and In Inventory", NEWLINE,
       "  flags). The Forbidden, Dump, and Trader flags can be manipulated when an actual book is in focus using", NEWLINE,
       "  the command keys displayed above the list.", NEWLINE,
       "- The actual book sections have a 'zoom to book' command allowing you to zoom to the location in your", NEWLINE,
       "  fortress where the book is (e.g. to determine whether it will cause trouble if forbidden). Warning!", NEWLINE,
       "  while it seems DF can be played from there, there are things known not to work properly. Return from", NEWLINE,
       "  this view with the Ook! command (added on top of the bottom frame for reference) when done viewing.", NEWLINE,
       "- The Science and Values pages also have a Remote Works list containing all works existing in the DF", NEWLINE,
       "  world outside of your fortress, allowing you to find out which works you might want to 'acquire' via", NEWLINE,
       "  raids...", NEWLINE,
       "Version 0.19 2020-08-03", NEWLINE,
       "Comments:", NEWLINE,
       "- The term 'work' is used above for a reason. A 'work' is a unique piece of written information. Currently", NEWLINE,
       "  it seems DF is restricted to a single 'work' per book/codex/scroll/quire, but the data structures allow", NEWLINE,
       "  for compilations of multiple 'works' in a single volume, and there's nothing saying one volume could not", NEWLINE,
       "  have a different set than another one.", NEWLINE,
       "- Similar to the previous point, a single 'work' can technically contain references to multiple topics, and", NEWLINE,
       "  a scientific information reference can technically contain data on multiple topics within the same", NEWLINE,
       "  science category. Works referencing multiple topics, including a historical work that has snuck in a", NEWLINE,
       "  values changing part in it, have been seen. Multiple scientific topics within the same category in", NEWLINE,
       "  the same referencs has not been seen by the author, and probably isn't used (multiple references can be", NEWLINE,
       "  used to the same effect).", NEWLINE,
       "- The reason the Authors page doesn't list all the works of the authors is that the author of this script", NEWLINE,
       "  hasn't been able to find it listed somewhere, and scouring the total list of works is expected to take too", NEWLINE,
       "  much time in worlds with many works. (There's already a noteceable lag when changing scientific/values", NEWLINE,
       "  changing topics in the author's world (> half a million works).", NEWLINE,
       "- The reason the Trader flag is available for toggling is that the author has encountered lots of questing", NEWLINE,
       "  and attacking visitors who leave books with that flag set behind, and it seems you can't move the book", NEWLINE,
       "  when it is set. The attackers clearly aren't traders, so that flag being set is probably a bug.", NEWLINE,
       "- Why is the command to return to The Librarian named 'Ook!'? 'l' and 'L' are used by DF, so a reference to", NEWLINE,
       "  the Discworld Librarian was used. If that's definitely not funny, change the 'dont_be_silly' variable at", NEWLINE,
       "  the beginning of this script to 'true'.", NEWLINE,
       "Caveats:", NEWLINE,
       "- The testing has been limited...", NEWLINE,
       "- Some data structures are changing. Usage of such data has been skipped for the time being.", NEWLINE,
       "- Only the Scientific and Values references are completely covered (anything missing is a bug or new data),", NEWLINE,
       "  but the coverage of the rest is spotty, limited to what happens to be available in the author's fortress.", NEWLINE,
       "  and what's there hasn't been subject to any touching up, so it provides the information in a crude format.", NEWLINE,
       "- The Dump flag of artifact works can be set by The Librarian (and is displayed by DF when that has been done)", NEWLINE,
       "  however, as DF doesn't allow the flag to be set normally and the author's fortress isn't playable, it hasn't", NEWLINE,
       "  been tested whether those books are actually dumped.", NEWLINE,
       "- The Hidden view brought up with zooming to books had issues with the up/down keys having side effects in the", NEWLINE,
       "  form of additional movements, causing them to exit lists. While that has been worked around, any other issues", NEWLINE,
       "  have not. It's known the DFHack naming function doesn't work, for instance."
       }
               
   return helptext
  end
  
  --============================================================

  function Ui:init ()
    self.stack = {}
    self.item_count = 0
    self.keys = {}
    
    local screen_width, screen_height = dfhack.screen.getWindowSize ()

    Main_Page.Background = 
      widgets.Label {text = {{text = "Help/Info",
                                      key = keybindings.help.key,
                                      key_sep = '()'},
                             {text = "      Works total:        Works listed:       Interactions:"},NEWLINE,
                             {text = "",
                                     key = keybindings.science.key,
                                     key_sep = '()'},
                             {text = " Science Page ",
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                     key = keybindings.values.key,
                                     key_sep = '()'},
                             {text = " Values Page ",
                              pen = COLOR_LIGHTBLUE}, 
                             {text = "",
                                     key = keybindings.authors.key,
                                     key_sep = '()'},
                             {text = " Authors Page ",
                              pen = COLOR_LIGHTBLUE}, 
                             {text = "",
                                     key = keybindings.interactions.key,
                                     key_sep = '()'},
                             {text = " Interactions Page ",
                              pen = COLOR_LIGHTBLUE}, NEWLINE,
                             {text = "",
                                     key = keybindings.content_type.key,
                                     key_sep = '()'},
                             {text = " Content Type:                                 ",
                              pen = COLOR_LIGHTBLUE},
                              {text = "",
                                     key = keybindings.reference_filter.key,
                                     key_sep = '()'},
                             {text = " Filter works without references:",
                              pen = COLOR_LIGHTBLUE}},
                     frame = {l = 0, t = 1, y_align = 0}}
    
    Main_Page.Works_Total =
      widgets.Label {text = "0",
                     frame = {l = 33, t = 1, y_align = 0},
                     text_pen = COLOR_WHITE}
                     
    Main_Page.Works_Listed =
      widgets.Label {text = "0",
                     frame = {l = 53, t = 1, y_align = 0},
                     text_pen = COLOR_WHITE}
    
    Main_Page.Interaction_Works =
      widgets.Label {text = "0",
                     frame = {l = 73, t = 1, y_align = 0},
                     text_pen = COLOR_WHITE}
    
    Main_Page.Stock = Take_Stock ()
    Main_Page.Filtered_Stock = Filter_Stock (Main_Page.Stock, Content_Type_Selected, Reference_Filter)

    table.insert (Content_Type_Map, {name = {[false] = "All (" .. tostring (#Main_Page.Stock) .. ")",
                                             [true] = "All (" .. tostring (#Filter_Stock (Main_Page.Stock, Content_Type_Selected, true)) .. ")"},
                                     index = -1})
                                     
    for i = df.written_content_type._first_item, df.written_content_type._last_item do
      table.insert (Content_Type_Map, {name = {[false] = df.written_content_type [i] .. " (" .. tostring (#Filter_Stock (Main_Page.Stock, i + 2, false)) .. ")",
                                               [true] = df.written_content_type [i] .. " (" .. tostring (#Filter_Stock (Main_Page.Stock, i + 2, true)) .. ")"},
                                       index = i})
    end

    Main_Page.Content_Type =
      widgets.Label {text = Content_Type_Map [Content_Type_Selected].name [false],
                     frame = {l = 19, t = 3, y_align = 0},
                     text_pen = COLOR_YELLOW}
      
    Main_Page.Reference_Filter =
      widgets.Label {text = Bool_To_YN (Reference_Filter),
                     frame = {l = 89, w = 1, t = 3, y_align = 0},
                     text_pen = COLOR_YELLOW}
      
    Main_Page.Details =
      widgets.Label {text = Produce_Details (nil),
                     frame = {l = 54, t = 6, h = 20, y_align = 0},
                     auto_height = false,
                     text_pen = COLOR_WHITE}
                     
    Main_Page.Book_List =
      widgets.List {view_id = "Books containting Work",
                    choices = {},
                    frame = {l = 54, t = 32, yalign = 0},
                    text_pen = COLOR_DARKGREY,
                    cursor_pen = COLOR_YELLOW,
                    inactive_pen = COLOR_GREY,
                    active = false}--,
--                    on_select = self:callback ("show_main_details")}
    
    Main_Page.List =
      widgets.List {view_id = "Selected Written Contents",
                    choices = Make_List (Main_Page.Filtered_Stock),
                    frame = {l = 1, w = 53, t = 6, yalign = 0},
                    text_pen = COLOR_DARKGREY,
                    cursor_pen = COLOR_YELLOW,
                    inactive_pen = COLOR_GREY,
                    on_select = self:callback ("show_main_details")}
    
    Main_Page.Active_List = {}
    table.insert (Main_Page.Active_List, Main_Page.List)
    table.insert (Main_Page.Active_List, Main_Page.Book_List)
    
    Main_Page.Book_Order_Label =
      widgets.Label {text = {{text = "",
                                     key = keybindings.forbid_book.key,
                                     key_sep = '()'},
                             {text = " Toggle Forbid Flag ",
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                     key = keybindings.dump_book.key,
                                     key_sep = '()'},
                             {text = " Toggle Dump Flag",
                              pen = COLOR_LIGHTBLUE},
                             NEWLINE,
                             {text = "",
                                     key = keybindings.trader_book.key,
                                     key_sep = '()'},
                             {text = " Toggle Trader Flag ",
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                     key = keybindings.zoom.key,
                                     key_sep = '()'},
                             {text = " Zoom to book (return with 'O')",
                              pen = COLOR_LIGHTBLUE}},
                     frame = {l = 54, t = 28, y_align = 0},
                     visible = false}
                     
    Main_Page.Book_Label =
      widgets.Label {text = "Books: O/C = Original/Copy, F = Forbidden, D = Dump, T = Trader, I = In Inventory",
                     frame = {l = 54, t = 30, y_align = 0},
                     text_pen = COLOR_WHITE}
    
    Main_Page.Works_Total:setText (tostring (#Main_Page.Stock))
    Main_Page.Works_Listed:setText (tostring (#Main_Page.List.choices))
        
    local mainPage = widgets.Panel {
      subviews = {Main_Page.Background,
                  Main_Page.Works_Total,
                  Main_Page.Works_Listed,
                  Main_Page.Content_Type,
                  Main_Page.Reference_Filter,
                  Main_Page.List,
                  Main_Page.Details,
                  Main_Page.Book_Order_Label,
                  Main_Page.Book_Label,
                  Main_Page.Book_List,
                  Main_Page.Interaction_Works}}
                
    local sciencePage = widgets.Panel {
      subviews = {}}
           
    Science_Page.Background =
      widgets.Label {text = {{text = "Help/Info",
                                      key = keybindings.help.key,
                                      key_sep = '()'},NEWLINE,
                             {text = "",
                                     key = keybindings.main.key,
                                     key_sep = '()'},
                             {text = " Main Page",
                              pen = COLOR_LIGHTBLUE},
                              {text = "",
                                     key = keybindings.values.key,
                                     key_sep = '()'},
                             {text = " Values Page",
                              pen = COLOR_LIGHTBLUE}, 
                             {text = "",
                                     key = keybindings.authors.key,
                                     key_sep = '()'},
                             {text = " Authors Page ",
                              pen = COLOR_LIGHTBLUE}, 
                             {text = "",
                                     key = keybindings.interactions.key,
                                     key_sep = '()'},
                             {text = " Interactions Page ",
                              pen = COLOR_LIGHTBLUE}, NEWLINE, NEWLINE, NEWLINE,
                             "Philosophy (0)", NEWLINE,
                             "Philosophy (1)", NEWLINE,
                             "Mathematics (2)", NEWLINE,
                             "Mathematics (3)", NEWLINE,
                             "History (4)", NEWLINE,
                             "Astronomy (5)", NEWLINE,
                             "Naturalist (6)", NEWLINE,
                             "Chemistry (7)", NEWLINE,
                             "Geography (8)", NEWLINE,
                             "Medicine (9)", NEWLINE,
                             "Medicine (10)", NEWLINE,
                             "Medicine (11)", NEWLINE,
                             "Engineering (12)", NEWLINE,
                             "Engineering (13)"}, 
                     frame = {l = 0, t = 1, y_align = 0}}
    
    table.insert (sciencePage.subviews, Science_Page.Background)
    
    Science_Page.Matrix = {}
    Science_Page.Data_Matrix = Take_Science_Stock (Main_Page.Stock)
    Science_Page.Remote_Data_Matrix = {}
    
    Values_Page.Matrix = {}
    Values_Page.Data_Matrix = Take_Values_Stock (Main_Page.Stock)
    Values_Page.Remote_Data_Matrix = {}
    
    Take_Remote_Stock ()
    
    for i = 0, 13 do  --  Haven't found an enum over the knowledge category range...
      Science_Page.Matrix [i] = {}
      
      for k = df.knowledge_scholar_flags_0._first_item, df.knowledge_scholar_flags_0._last_item do  --  Full bit range, rather than used bit range, but same for all...
        if check_flag ("knowledge_scholar_flags_" .. tostring (i), k) then
          Science_Page.Matrix [i] [k] =
            widgets.Label {text = Science_Character_Of (Science_Page.Data_Matrix, i, k),
                           frame = {l = 18 + k * 2, w = 1, t = 5 + i, y_align = 0},
                           text_pen = Science_Color_Of (Science_Page.Data_Matrix, i, k)}
          table.insert (sciencePage.subviews, Science_Page.Matrix [i] [k])
        end
      end
    end    
    
    Science_Page.Background_2 =
      widgets.Label {text = "Category  Scientific Topic                                                         Local Knowledge",
                     frame = {l = 0, t = 21, y_align = 0}}
                     
    table.insert (sciencePage.subviews, Science_Page.Background_2)

    Science_Page.Background_3 =
      widgets.Label {text = "Remote Knowledge",
                     frame = {l = 83, t = 38, y_align = 0}}
                     
    table.insert (sciencePage.subviews, Science_Page.Background_3)
    
    local category_list = {}
    for i = 0, 13 do
      table.insert (category_list, tostring (i))
    end
    
    Science_Page.Topic_List =
      widgets.List {view_id = "Topic",
                    choices = category_list,  --  Placeholder
                    frame = {l = 10, t = 23, h = 20, yalign = 0},
                    text_pen = COLOR_DARKGREY,
                    cursor_pen = COLOR_YELLOW,
                    inactive_pen = COLOR_GREY,
                    active = false,
                    on_select = self:callback ("show_science_titles")}
    
    Science_Page.Category_List =
      widgets.List {view_id = "Category",
                    choices = category_list,
                    frame = {l = 4, w = 2, h = 20, t = 23, yalign = 0},
                    text_pen = COLOR_DARKGREY,
                    cursor_pen = COLOR_YELLOW,
                    inactive_pen = COLOR_GREY,
                    on_select = self:callback ("show_science_topic")}

    Science_Page.Details =
      widgets.Label {text = Produce_Details (nil),
                     frame = {l = 82, t = 1, h = 20, y_align = 0},
                     auto_height = false,
                     text_pen = COLOR_WHITE}
                     
    Science_Page.Book_List =
      widgets.List {view_id = "Books containting Work",
                    choices = {},
                    frame = {l = 1, t = 49, yalign = 0},
                    text_pen = COLOR_DARKGREY,
                    cursor_pen = COLOR_YELLOW,
                    inactive_pen = COLOR_GREY,
                    active = false}--,
--                    on_select = self:callback ("show_main_details")}
    
    Science_Page.Own_List =
      widgets.List {view_id = "Own",
                    choices = category_list,  --  Placeholder
                    frame = {l = 83, t = 23, h = 15, yalign = 0},
                    text_pen = COLOR_DARKGREY,
                    cursor_pen = COLOR_YELLOW,
                    inactive_pen = COLOR_GREY,
                    active = false,
                    on_select = self:callback ("show_science_local_details")}

    Science_Page.Remote_List =
      widgets.List {view_id = "Remote",
                    choices = category_list,  --  Placeholder
                    frame = {l = 83, t = 40, h = 15, yalign = 0},
                    text_pen = COLOR_DARKGREY,
                    cursor_pen = COLOR_YELLOW,
                    inactive_pen = COLOR_GREY,
                    active = false,
                    on_select = self:callback ("show_science_remote_details")}

    Science_Page.Book_Order_Label =
      widgets.Label {text = {{text = "",
                                     key = keybindings.forbid_book.key,
                                     key_sep = '()'},
                             {text = " Toggle Forbid Flag ",
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                     key = keybindings.dump_book.key,
                                     key_sep = '()'},
                             {text = " Toggle Dump Flag",
                              pen = COLOR_LIGHTBLUE},
                             NEWLINE,
                             {text = "",
                                     key = keybindings.trader_book.key,
                                     key_sep = '()'},
                             {text = " Toggle Trader Flag ",
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                     key = keybindings.zoom.key,
                                     key_sep = '()'},
                             {text = " Zoom to book (return with 'O')",
                              pen = COLOR_LIGHTBLUE}},
                     frame = {l = 1, t = 45, y_align = 0},
                     visible = false}
                     
    Science_Page.Book_Label =
      widgets.Label {text = "Books: O/C = Original/Copy, F = Forbidden, D = Dump, T = Trader, I = In Inventory",
                     frame = {l = 1, t = 47, y_align = 0},
                     text_pen = COLOR_WHITE}
    
    table.insert (sciencePage.subviews, Science_Page.Category_List)
    table.insert (sciencePage.subviews, Science_Page.Topic_List)
    table.insert (sciencePage.subviews, Science_Page.Own_List)
    table.insert (sciencePage.subviews, Science_Page.Remote_List)
    table.insert (sciencePage.subviews, Science_Page.Details)
    table.insert (sciencePage.subviews, Science_Page.Book_Order_Label)
    table.insert (sciencePage.subviews, Science_Page.Book_Label)
    table.insert (sciencePage.subviews, Science_Page.Book_List)
    
    Science_Page.Active_List = {}
    
    table.insert (Science_Page.Active_List, Science_Page.Category_List)
    table.insert (Science_Page.Active_List, Science_Page.Topic_List)
    table.insert (Science_Page.Active_List, Science_Page.Own_List)
    table.insert (Science_Page.Active_List, Science_Page.Book_List)
    table.insert (Science_Page.Active_List, Science_Page.Remote_List)    
    
    local valuesPage = widgets.Panel {
      subviews = {}}
      
    Values_Page.Background =    
      widgets.Label {text = {{text = "Help/Info",
                                      key = keybindings.help.key,
                                      key_sep = '()'},NEWLINE,
                             {text = "",
                                     key = keybindings.main.key,
                                     key_sep = '()'},
                             {text = " Main Page",
                              pen = COLOR_LIGHTBLUE},
                              {text = "",
                                     key = keybindings.science.key,
                                     key_sep = '()'},
                             {text = " Science Page",
                              pen = COLOR_LIGHTBLUE}, 
                             {text = "",
                                     key = keybindings.authors.key,
                                     key_sep = '()'},
                             {text = " Authors Page ",
                              pen = COLOR_LIGHTBLUE}, 
                             {text = "",
                                     key = keybindings.interactions.key,
                                     key_sep = '()'},
                             {text = " Interactions Page ",
                              pen = COLOR_LIGHTBLUE}, NEWLINE, NEWLINE,
                             {text = "Value           "},
                             {text = "3 2 1 ",
                              pen = COLOR_LIGHTRED},
                             {text = "0 ",
                              pen = COLOR_YELLOW},
                             {text = "1 2 3",
                              pen = COLOR_GREEN},
                             {text = "  Strength        Own"}},
                     frame = {l = 0, t = 1, y_align = 0}}
    
    table.insert (valuesPage.subviews, Values_Page.Background)
    
    Values_Page.Background_2 =
      widgets.Label {text = "Remote",
                     frame = {l = 47, t = 21, y_align = 0}}
                     
    table.insert (valuesPage.subviews, Values_Page.Background_2)
    
    local values_background = {}
    
    for i, value in ipairs (df.value_type) do
      if i ~= df.value_type.NONE then
        Values_Page.Matrix [i] = {}
        table.insert (values_background, df.value_type [i])
      
        for k = -3, 3 do
          Values_Page.Matrix [i] [k] =
            widgets.Label {text = Science_Character_Of (Values_Page.Data_Matrix, i, k),
                           frame = {l = 22 + k * 2, w = 1, t = 6 + i, y_align = 0},
                           text_pen = Science_Color_Of (Values_Page.Data_Matrix, i, k)}
          table.insert (valuesPage.subviews, Values_Page.Matrix [i] [k])
        end
      end
    end
    
    Values_Page.Values_List =
      widgets.List {view_id = "Values",
                    choices = values_background,
                    frame = {l = 0, t = 6, yalign = 0},
                    text_pen = COLOR_DARKGREY,
                    cursor_pen = COLOR_YELLOW,
                    inactive_pen = COLOR_GREY,
                    on_select = self:callback ("show_values")}

    table.insert (valuesPage.subviews, Values_Page.Values_List)
    
    local values_strengths =
      {"Hate",
       "Strong Dislike",
       "Dislike",
       "Indifference",
       "Like",
       "Strong Liking",
       "Love"}

    Values_Page.Strength_List =
      widgets.List {view_id = "Strengths",
                    choices = values_strengths,
                    frame = {l = 31, t = 6, yalign = 0},
                    text_pen = COLOR_DARKGREY,
                    cursor_pen = COLOR_YELLOW,
                    inactive_pen = COLOR_GREY,
                    on_select = self:callback ("show_values"),
                    active = false}
    
    table.insert (valuesPage.subviews, Values_Page.Strength_List)
    
    Values_Page.Details =
      widgets.Label {text = Produce_Details (nil),
                     frame = {l = 0, t = 40, h = 20, y_align = 0},
                     auto_height = false,
                     text_pen = COLOR_WHITE}
                     
    Values_Page.Book_List =
      widgets.List {view_id = "Books containting Work",
                    choices = {},
                    frame = {l = 1, t = 66, yalign = 0},
                    text_pen = COLOR_DARKGREY,
                    cursor_pen = COLOR_YELLOW,
                    inactive_pen = COLOR_GREY,
                    active = false}--,
--                    on_select = self:callback ("show_main_details")}
    
    Values_Page.Own_List =
      widgets.List {view_id = "Own",
                    choices = category_list,  --  Placeholder
                    frame = {l = 47, t = 6, h = 15, yalign = 0},
                    text_pen = COLOR_DARKGREY,
                    cursor_pen = COLOR_YELLOW,
                    inactive_pen = COLOR_GREY,
                    active = false,
                    on_select = self:callback ("show_values_local_details")}

    table.insert (valuesPage.subviews, Values_Page.Own_List)
    
    Values_Page.Remote_List =
      widgets.List {view_id = "Remote",
                    choices = category_list,  --  Placeholder
                    frame = {l = 47, t = 23, h = 15, yalign = 0},
                    text_pen = COLOR_DARKGREY,
                    cursor_pen = COLOR_YELLOW,
                    inactive_pen = COLOR_GREY,
                    active = false,
                    on_select = self:callback ("show_values_remote_details")}

    table.insert (valuesPage.subviews, Values_Page.Remote_List)
    table.insert (valuesPage.subviews, Values_Page.Details)
    table.insert (valuesPage.subviews, Values_Page.Book_List)

    Values_Page.Book_Order_Label =
      widgets.Label {text = {{text = "",
                                     key = keybindings.forbid_book.key,
                                     key_sep = '()'},
                             {text = " Toggle Forbid Flag ",
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                     key = keybindings.dump_book.key,
                                     key_sep = '()'},
                             {text = " Toggle Dump Flag",
                              pen = COLOR_LIGHTBLUE},
                             NEWLINE,
                             {text = "",
                                     key = keybindings.trader_book.key,
                                     key_sep = '()'},
                             {text = " Toggle Trader Flag ",
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                     key = keybindings.zoom.key,
                                     key_sep = '()'},
                             {text = " Zoom to book (return with 'O')",
                              pen = COLOR_LIGHTBLUE}},
                     frame = {l = 1, t = 62, y_align = 0},
                     visible = false}
                     
    table.insert (valuesPage.subviews, Values_Page.Book_Order_Label)
    
    Values_Page.Book_Label =
      widgets.Label {text = "Books: O/C = Original/Copy, F = Forbidden, D = Dump, T = Trader, I = In Inventory",
                     frame = {l = 1, t = 64, y_align = 0},
                     text_pen = COLOR_WHITE}
    
    table.insert (valuesPage.subviews, Values_Page.Book_Label)

    Values_Page.Active_List = {}
    
    table.insert (Values_Page.Active_List, Values_Page.Values_List)
    table.insert (Values_Page.Active_List, Values_Page.Strength_List)
    table.insert (Values_Page.Active_List, Values_Page.Own_List)
    table.insert (Values_Page.Active_List, Values_Page.Book_List)
    table.insert (Values_Page.Active_List, Values_Page.Remote_List)
    
    local authorsPage = widgets.Panel {
      subviews = {}}
      
    Authors_Page.Background =
      widgets.Label {text = {{text = "Help/Info",
                                      key = keybindings.help.key,
                                      key_sep = '()'},NEWLINE,
                             {text = "",
                                     key = keybindings.main.key,
                                     key_sep = '()'},
                             {text = " Main Page",
                              pen = COLOR_LIGHTBLUE},
                              {text = "",
                                     key = keybindings.science.key,
                                     key_sep = '()'},
                             {text = " Science Page",
                              pen = COLOR_LIGHTBLUE}, 
                             {text = "",
                                     key = keybindings.values.key,
                                     key_sep = '()'},
                             {text = " Values Page ",
                              pen = COLOR_LIGHTBLUE}, 
                             {text = "",
                                     key = keybindings.interactions.key,
                                     key_sep = '()'},
                             {text = " Interactions Page ",
                              pen = COLOR_LIGHTBLUE}, NEWLINE, NEWLINE,
                             {text = "Authors"}},
                     frame = {l = 0, t = 1, y_align = 0}}
    
    table.insert (authorsPage.subviews, Authors_Page.Background)
    
    Authors_Page.Authors = Take_Authors_Stock (Main_Page.Stock)
    
    local authors_list = {}
    
    for i, element in ipairs (Authors_Page.Authors) do
      table.insert (authors_list, element [1])
    end
    
    Authors_Page.Details =
      widgets.Label {text = Produce_Details (nil),
                     frame = {l = 65, t = 24, h = 20, y_align = 0},
                     auto_height = false,
                     text_pen = COLOR_WHITE}
                     
    Authors_Page.Book_List =
      widgets.List {view_id = "Books containting Work",
                    choices = {},
                    frame = {l = 65, t = 50, yalign = 0},
                    text_pen = COLOR_DARKGREY,
                    cursor_pen = COLOR_YELLOW,
                    inactive_pen = COLOR_GREY,
                    active = false}--,
--                    on_select = self:callback ("show_main_details")}
    
    Authors_Page.Works_List =
      widgets.List {view_id = "Works",
                    choices = {},
                    frame = {l = 1, t = 24, h = 15, yalign = 0},
                    text_pen = COLOR_DARKGREY,
                    cursor_pen = COLOR_YELLOW,
                    inactive_pen = COLOR_GREY,
                    active = false,
                    on_select = self:callback ("show_authors_details")}
    
    table.insert (authorsPage.subviews, Authors_Page.Works_List)
    
    Authors_Page.Authors_List =
      widgets.List {view_id = "Authors",
                    choices = authors_list,
                    frame = {l = 1, t = 6, h = 15, yalign = 0},
                    text_pen = COLOR_DARKGREY,
                    cursor_pen = COLOR_YELLOW,
                    inactive_pen = COLOR_GREY,
                    active = true,
                    on_select = self:callback ("show_authors_titles")}
    
    table.insert (authorsPage.subviews, Authors_Page.Authors_List)
    table.insert (authorsPage.subviews, Authors_Page.Details)
    table.insert (authorsPage.subviews, Authors_Page.Book_List)
    
    Authors_Page.Background_2 =
      widgets.Label {text = {{text = " Works                                                           Details"}},
                     frame = {l = 0, t = 22, y_align = 0}}
    
    table.insert (authorsPage.subviews, Authors_Page.Background_2)
    
    Authors_Page.Book_Order_Label =
      widgets.Label {text = {{text = "",
                                     key = keybindings.forbid_book.key,
                                     key_sep = '()'},
                             {text = " Toggle Forbid Flag ",
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                     key = keybindings.dump_book.key,
                                     key_sep = '()'},
                             {text = " Toggle Dump Flag",
                              pen = COLOR_LIGHTBLUE},
                             NEWLINE,
                             {text = "",
                                     key = keybindings.trader_book.key,
                                     key_sep = '()'},
                             {text = " Toggle Trader Flag ",
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                     key = keybindings.zoom.key,
                                     key_sep = '()'},
                             {text = " Zoom to book (return with 'O')",
                              pen = COLOR_LIGHTBLUE}},
                     frame = {l = 65, t = 46, y_align = 0},
                     visible = false}
                     
    table.insert (authorsPage.subviews, Authors_Page.Book_Order_Label)
    
    Authors_Page.Book_Label =
      widgets.Label {text = "Books: O/C = Original/Copy, F = Forbidden, D = Dump, T = Trader, I = In Inventory",
                     frame = {l = 65, t = 48, y_align = 0},
                     text_pen = COLOR_WHITE}
    
    table.insert (authorsPage.subviews, Authors_Page.Book_Label)

    Authors_Page.Active_List = {}
    
    table.insert (Authors_Page.Active_List, Authors_Page.Authors_List)
    table.insert (Authors_Page.Active_List, Authors_Page.Works_List)
    table.insert (Authors_Page.Active_List, Authors_Page.Book_List)

    local interactionsPage = widgets.Panel {
      subviews = {}}
      
    Interactions_Page.Background =
      widgets.Label {text = {{text = "Help/Info",
                                      key = keybindings.help.key,
                                      key_sep = '()'},NEWLINE,
                             {text = "",
                                     key = keybindings.main.key,
                                     key_sep = '()'},
                             {text = " Main Page",
                              pen = COLOR_LIGHTBLUE},
                              {text = "",
                                     key = keybindings.science.key,
                                     key_sep = '()'},
                             {text = " Science Page",
                              pen = COLOR_LIGHTBLUE}, 
                             {text = "",
                                     key = keybindings.values.key,
                                     key_sep = '()'},
                             {text = " Values Page ",
                              pen = COLOR_LIGHTBLUE}, 
                             {text = "",
                                     key = keybindings.authors.key,
                                     key_sep = '()'},
                             {text = " Authors Page ",
                              pen = COLOR_LIGHTBLUE}, NEWLINE, NEWLINE,
                             {text = "Interaction Works"}},
                     frame = {l = 0, t = 1, y_align = 0}}
    
    table.insert (interactionsPage.subviews, Interactions_Page.Background)
    
    Interactions_Page.Interactions = Take_Interactions_Stock (Main_Page.Stock)
    
    local interactions_list = {}
    
    for i, element in ipairs (Interactions_Page.Interactions) do
      local content = df.written_content.find (element [2] [1])
      local title = ""
    
      if content then
        title = content.title
      end
    
      if title == "" then
        title = "<Untitled>"
      end

      table.insert (interactions_list, title .. ": " .. element [1])
    end
    
    Interactions_Page.Works_List =
      widgets.List {view_id = "Works",
                    choices = interactions_list,
                    frame = {l = 1, t = 6, h = 15, yalign = 0},
                    text_pen = COLOR_DARKGREY,
                    cursor_pen = COLOR_YELLOW,
                    inactive_pen = COLOR_GREY,
                    active = true,
                    on_select = self:callback ("show_interactions_details")}
    
    if #Interactions_Page.Interactions == 0 then
      Interactions_Page.Details =
        widgets.Label {text = " ",
                       frame = {l = 65, t = 24, h = 20, y_align = 0},
                       auto_height = false,
                       text_pen = COLOR_WHITE}
    else
      Interactions_Page.Details =
        widgets.Label {text = Produce_Details (Interactions_Page.Interactions [Interactions_Page.Works_List.selected] [2]),
                       frame = {l = 65, t = 24, h = 20, y_align = 0},
                       auto_height = false,
                       text_pen = COLOR_WHITE}
    end
    
    table.insert (interactionsPage.subviews, Interactions_Page.Works_List)    
    table.insert (interactionsPage.subviews, Interactions_Page.Details)
    
    Interactions_Page.Background_2 =
      widgets.Label {text = {{text = "                                                                 Details"}},
                     frame = {l = 0, t = 22, y_align = 0}}
    
    table.insert (interactionsPage.subviews, Interactions_Page.Background_2)
    
    Interactions_Page.Book_Order_Label =
      widgets.Label {text = {{text = "",
                                     key = keybindings.forbid_book.key,
                                     key_sep = '()'},
                             {text = " Toggle Forbid Flag ",
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                     key = keybindings.dump_book.key,
                                     key_sep = '()'},
                             {text = " Toggle Dump Flag",
                              pen = COLOR_LIGHTBLUE},
                             NEWLINE,
                             {text = "",
                                     key = keybindings.trader_book.key,
                                     key_sep = '()'},
                             {text = " Toggle Trader Flag ",
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                     key = keybindings.zoom.key,
                                     key_sep = '()'},
                             {text = " Zoom to book (return with 'O')",
                              pen = COLOR_LIGHTBLUE}},
                     frame = {l = 65, t = 46, y_align = 0},
                     visible = false}
                     
    table.insert (interactionsPage.subviews, Interactions_Page.Book_Order_Label)
    
    Interactions_Page.Book_Label =
      widgets.Label {text = "Books: O/C = Original/Copy, F = Forbidden, D = Dump, T = Trader, I = In Inventory",
                     frame = {l = 65, t = 48, y_align = 0},
                     text_pen = COLOR_WHITE}
    
    table.insert (interactionsPage.subviews, Interactions_Page.Book_Label)

    Interactions_Page.Active_List = {}
    
    table.insert (Interactions_Page.Active_List, Interactions_Page.Works_List)

    Main_Page.Interaction_Works:setText (tostring (#Interactions_Page.Works_List.choices))

    local hiddenPage = widgets.Panel {
      subviews = {}}
           
    Help_Page.Main = 
      widgets.Label
        {text = Helptext_Main (),
         frame = {l = 1, t = 1, yalign = 0},
         visible = true}
    
    helpPage = widgets.Panel
      {subviews = {Help_Page.Main}}
                   
    local pages = widgets.Pages 
      {subviews = {mainPage,
                   sciencePage,
                   valuesPage,
                   authorsPage,
                   interactionsPage,
                   hiddenPage,
                   helpPage},view_id = "pages",
                   }

    pages:setSelected (1)
    Focus = "Main"
      
    self:addviews {pages}
  end

  --==============================================================

  function Ui:show_main_details (index, choice)
    if index == nil or #Main_Page.Filtered_Stock < index then
      Main_Page.Details:setText (Produce_Details (nil))
      Main_Page.Book_List:setChoices (Produce_Book_List (nil))
      
    else
      Main_Page.Details:setText (Produce_Details (Main_Page.Filtered_Stock [index].element))
      Main_Page.Book_List:setChoices (Produce_Book_List (Main_Page.Filtered_Stock [index].element [2]), 1)
    end
  end
  
  --==============================================================

  function Ui:show_science_topic (index, choice)
    local list = {}

    for i = df.knowledge_scholar_flags_0._first_item, df.knowledge_scholar_flags_0._last_item do  --  Don't care about the actual flag. Will iterate over all "bits" anyway.
      if check_flag ("knowledge_scholar_flags_" .. tostring (index - 1), i) then
        table.insert (list, knowledge [index - 1] [i])
      end
    end
   
    Science_Page.Topic_List:setChoices (list, 1)
    
    Populate_Own_Remote_Science ()
  end
  
  --==============================================================

  function Ui:show_science_titles (index, choice)
    Populate_Own_Remote_Science ()
  end
  
  --==============================================================

  function Ui:show_science_local_details (index, choice)
    if Science_Page.Own_List then  --  Else initiation
      if Science_Page.Own_List.active then
        Science_Page.Details:setText (Produce_Details (Science_Page.Data_Matrix [Science_Page.Category_List.selected - 1]
                                                                                [Science_Page.Topic_List.selected - 1]
                                                                                [index]))
        Science_Page.Book_List:setChoices (Produce_Book_List (Science_Page.Data_Matrix [Science_Page.Category_List.selected - 1]
                                                                                       [Science_Page.Topic_List.selected - 1]
                                                                                       [index] [2]), 1)
      end
    end
  end
  
  --==============================================================

  function Ui:show_science_remote_details (index, choice)
    if Science_Page.Remote_List then  --  Else initiation
      if Science_Page.Remote_List.active then
        Science_Page.Details:setText (Produce_Details ({Science_Page.Remote_Data_Matrix [Science_Page.Category_List.selected - 1]
                                                                                        [Science_Page.Topic_List.selected - 1]
                                                                                        [index].id}))
      end
    end
  end
  
  --==============================================================

  function Ui:on_select_content_type (index, choice)
    Content_Type_Selected = index
    Main_Page.Content_Type:setText (Content_Type_Map [Content_Type_Selected].name [Reference_Filter])
    Main_Page.Filtered_Stock = Filter_Stock (Main_Page.Stock, Content_Type_Selected, Reference_Filter)
    Main_Page.List:setChoices (Make_List (Main_Page.Filtered_Stock))
    Main_Page.Works_Listed:setText (tostring (#Main_Page.List.choices))
  end
  
  --==============================================================

  function Ui:show_values (index, choice)
    Populate_Own_Remote_Values ()
  end
  
  --==============================================================

  function Ui:show_values_local_details (index, choice)
    if Values_Page.Own_List then  --  Else initiation
      if Values_Page.Own_List.active then
        Values_Page.Details:setText (Produce_Details (Values_Page.Data_Matrix [Values_Page.Values_List.selected - 1]
                                                                              [Values_Page.Strength_List.selected - 4]
                                                                              [index]))
        Values_Page.Book_List:setChoices (Produce_Book_List (Values_Page.Data_Matrix [Values_Page.Values_List.selected - 1]
                                                                                     [Values_Page.Strength_List.selected - 4]
                                                                                     [index] [2]), 1)
      end
    end
  end
  
  --==============================================================

  function Ui:show_values_remote_details (index, choice)
    if Values_Page.Remote_List then  --  Else initiation
      if Values_Page.Remote_List.active then
        Values_Page.Details:setText (Produce_Details ({Values_Page.Remote_Data_Matrix [Values_Page.Values_List.selected - 1]
                                                                                      [Values_Page.Strength_List.selected - 4]
                                                                                      [Values_Page.Remote_List_Map [index]].id}))
      end
    end
  end
  
  --==============================================================

  function Ui:show_authors_titles (index, choice)
    Populate_Author_Works ()
  end
  
  --==============================================================

  function Ui:show_authors_details (index, choice)
    if Authors_Page.Works_List then  --  Else initiation
      if Authors_Page.Works_List.active then
        Authors_Page.Details:setText (Produce_Details (Authors_Page.Authors [Authors_Page.Authors_List.selected]
                                                                            [2]
                                                                            [index]))
        Authors_Page.Book_List:setChoices (Produce_Book_List (Authors_Page.Authors [Authors_Page.Authors_List.selected]
                                                                                   [2]
                                                                                   [index] [2]), 1)
      end
    end
  end
  
  --==============================================================

  function Ui:show_interactions_details (index, choice)
    if Interactions_Page.Works_List then  --  Else initiation
      if Interactions_Page.Works_List.active then
        Interactions_Page.Details:setText (Produce_Details (Interactions_Page.Interactions [Interactions_Page.Works_List.selected] [2]))
      end
    end
  end
  
  --==============================================================

  function Ui:onInput (keys)
    if keys.LEAVESCREEN_ALL then
        self:dismiss ()
    end
    
    if keys.LEAVESCREEN then
      if Focus == "Hidden" then
        persist_screen:sendInputToParent (keys)
      
      elseif Focus == "Help" then
        if Pre_Help_Focus == "Main" then
          self.subviews.pages:setSelected (1)
                
        elseif Pre_Help_Focus == "Science" then
          self.subviews.pages:setSelected (2)
          
        elseif Pre_Help_Focus == "Values" then
          self.subviews.pages:setSelected (3)
          
        elseif Pre_Help_Focus == "Authors" then
          self.subviews.pages:setSelected (4)
          
        elseif Pre_Help_Focus == "Interactions" then
          self.subviews.pages:setSelected (5)
        end
        
        Focus = Pre_Help_Focus
        
      else  --###  Should add confirmation
        self:dismiss ()
      end
    end

    if keys [keybindings.content_type.key] and
       Focus == "Main" then
      list = {}
      for i, element in ipairs (Content_Type_Map) do
        table.insert (list, element.name [Reference_Filter])
      end
      
      dialog.showListPrompt ("Select Content Type filter",
                             "Filter the title list to show only the ones in the\n" ..
                              "specified Content Type category.", --### Add display of current selection
                              COLOR_WHITE,
                              list, 
                              self:callback ("on_select_content_type"))
                              
    elseif keys [keybindings.reference_filter.key] and Focus == "Main" then
      Reference_Filter = not Reference_Filter
      Main_Page.Reference_Filter:setText (Bool_To_YN (Reference_Filter))
      Main_Page.Content_Type:setText (Content_Type_Map [Content_Type_Selected].name [Reference_Filter])
      Main_Page.Filtered_Stock = Filter_Stock (Main_Page.Stock, Content_Type_Selected, Reference_Filter)
      Main_Page.List:setChoices (Make_List (Main_Page.Filtered_Stock))
      Main_Page.Works_Listed:setText (tostring (#Main_Page.List.choices))
          
    elseif keys [keybindings.main.key] and 
           (Focus == "Science" or
            Focus == "Values" or
            Focus == "Authors" or
            Focus == "Interactions") then
      Focus = "Main"
      self.subviews.pages:setSelected (1)
            
    elseif keys [keybindings.science.key] and 
           (Focus == "Main" or
            Focus == "Values" or
            Focus == "Authors" or
            Focus == "Interactions") then
      Focus = "Science"
      Populate_Own_Remote_Science ()
      self.subviews.pages:setSelected (2)
            
    elseif keys [keybindings.values.key] and 
           (Focus == "Main" or
            Focus == "Science" or
            Focus == "Authors" or
            Focus == "Interactions") then
      Focus = "Values"
      Populate_Own_Remote_Values ()
      self.subviews.pages:setSelected (3)
            
    elseif keys [keybindings.authors.key] and 
           (Focus == "Main" or
            Focus == "Science" or
            Focus == "Values" or
            Focus == "Interactions") then
      Focus = "Authors"
      self.subviews.pages:setSelected (4)
            
    elseif keys [keybindings.interactions.key] and 
           (Focus == "Main" or
            Focus == "Science" or
            Focus == "Values" or
            Focus == "Authors") then
      Focus = "Interactions"
      self.subviews.pages:setSelected (5)
            
    elseif keys [keybindings.ook.key] and
           Focus == "Hidden" then
      if Pre_Hiding_Focus == "Main" then
        self.subviews.pages:setSelected (1)
        
      elseif Pre_Hiding_Focus == "Science" then
        self.subviews.pages:setSelected (2)
      
      elseif Pre_Hiding_Focus == "Values" then
        self.subviews.pages:setSelected (3)
      
      elseif Pre_Hiding_Focus == "Authors" then
        self.subviews.pages:setSelected (4)
      
      elseif Pre_Hiding_Focus == "Interactions" then
        self.subviews.pages:setSelected (5)
      end
      
      Focus = Pre_Hiding_Focus
      self.transparent = false
    
    elseif keys [keybindings.left.key] and 
           Focus == "Main" then
      local active = 1
      
      for i, list in ipairs (Main_Page.Active_List) do
        if list.active then
          active = i - 1
          
          if active == 0 then
            active = #Main_Page.Active_List
          end
          
          break
        end
      end
      
      for i, list in ipairs (Main_Page.Active_List) do
        list.active = (i == active)
      end
           
      Main_Page.Book_Order_Label.visible = Main_Page.Book_List.active
      
    elseif keys [keybindings.right.key] and 
           Focus == "Main" then
      local active = 1
      
      for i, list in ipairs (Main_Page.Active_List) do
        if list.active then
          active = i + 1
          
          if active > #Main_Page.Active_List then
            active = 1
          end
          
          break
        end
      end
      
      for i, list in ipairs (Main_Page.Active_List) do
        list.active = (i == active)
      end
           
      Main_Page.Book_Order_Label.visible = Main_Page.Book_List.active
      
    elseif keys [keybindings.left.key] and 
           Focus == "Science" then
      local active = 1
      
      for i, list in ipairs (Science_Page.Active_List) do
        if list.active then
          active = i - 1
          
          if active == 0 then
            active = #Science_Page.Active_List
          end
          
          break
        end
      end
      
      for i, list in ipairs (Science_Page.Active_List) do
        list.active = (i == active)
      end
           
      if Science_Page.Own_List.active then
        --  nothing
        
      elseif Science_Page.Remote_List.active then
        if #Science_Page.Remote_List.choices == 0 then
          Science_Page.Details:setText (Produce_Details (nil))
          
        else
          Science_Page.Details:setText (Produce_Details ({Science_Page.Remote_Data_Matrix
            [Science_Page.Category_List.selected - 1]
            [Science_Page.Topic_List.selected - 1]
            [Science_Page.Remote_List_Map [Science_Page.Remote_List.selected]].id}))
        end
       
      elseif Science_Page.Book_List.active then       
        if #Science_Page.Own_List.choices == 0 then
          Science_Page.Details:setText (Produce_Details (nil))
          Science_Page.Book_List:setChoices (Produce_Book_List (nil))
          
        else
          Science_Page.Details:setText (Produce_Details (Science_Page.Data_Matrix [Science_Page.Category_List.selected - 1]
                                                                                  [Science_Page.Topic_List.selected - 1]
                                                                                  [Science_Page.Own_List.selected]))
          Science_Page.Book_List:setChoices (Produce_Book_List (Science_Page.Data_Matrix [Science_Page.Category_List.selected - 1]
                                                                                         [Science_Page.Topic_List.selected - 1]
                                                                                         [Science_Page.Own_List.selected] [2]))
        end
      else
        Science_Page.Details:setText (Produce_Details (nil))
      end
 
      Science_Page.Book_Order_Label.visible = Science_Page.Book_List.active
      Science_Page.Book_List.visible = Science_Page.Own_List.active or
                                       Science_Page.Book_List.active      
 
    elseif keys [keybindings.right.key] and 
           Focus == "Science" then
      local active = 1
      
      for i, list in ipairs (Science_Page.Active_List) do
        if list.active then
          active = i + 1
          
          if active > #Science_Page.Active_List then
            active = 1
          end
          
          break
        end
      end
      
      for i, list in ipairs (Science_Page.Active_List) do
        list.active = (i == active)
      end
           
      if Science_Page.Own_List.active then
        if #Science_Page.Own_List.choices == 0 then
          Science_Page.Details:setText (Produce_Details (nil))
          Science_Page.Book_List:setChoices (Produce_Book_List (nil))
          
        else
          Science_Page.Details:setText (Produce_Details (Science_Page.Data_Matrix [Science_Page.Category_List.selected - 1]
                                                                                  [Science_Page.Topic_List.selected - 1]
                                                                                  [Science_Page.Own_List.selected]))
          Science_Page.Book_List:setChoices (Produce_Book_List (Science_Page.Data_Matrix [Science_Page.Category_List.selected - 1]
                                                                                         [Science_Page.Topic_List.selected - 1]
                                                                                         [Science_Page.Own_List.selected] [2]))
        end
      
      elseif Science_Page.Book_List.active then
        --  nothing
        
      elseif Science_Page.Remote_List.active then
        if #Science_Page.Remote_List.choices == 0 then
          Science_Page.Details:setText (Produce_Details (nil))
          
        else
          Science_Page.Details:setText (Produce_Details ({Science_Page.Remote_Data_Matrix
            [Science_Page.Category_List.selected - 1]
            [Science_Page.Topic_List.selected - 1]
            [Science_Page.Remote_List_Map [Science_Page.Remote_List.selected]].id}))
        end
        
      else
        Science_Page.Details:setText (Produce_Details (nil))
      end

      Science_Page.Book_Order_Label.visible = Science_Page.Book_List.active
      Science_Page.Book_List.visible = Science_Page.Own_List.active or
                                       Science_Page.Book_List.active      
      
    elseif keys [keybindings.left.key] and 
           Focus == "Values" then
      local active = 1
      
      for i, list in ipairs (Values_Page.Active_List) do
        if list.active then
          active = i - 1
          
          if active == 0 then
            active = #Values_Page.Active_List
          end
          
          break
        end
      end
      
      for i, list in ipairs (Values_Page.Active_List) do
        list.active = (i == active)
      end
       
      if Values_Page.Own_List.active then
        --  nothing
        
      elseif Values_Page.Remote_List.active then
        if #Values_Page.Remote_List.choices == 0 then
          Values_Page.Details:setText (Produce_Details (nil))
          
        else        
          Values_Page.Details:setText (Produce_Details ({Values_Page.Remote_Data_Matrix
            [Values_Page.Values_List.selected - 1]
            [Values_Page.Strength_List.selected - 4]
            [Values_Page.Remote_List_Map [Values_Page.Remote_List.selected]].id}))
        end
        
      elseif Values_Page.Book_List.active then
        if #Values_Page.Own_List.choices == 0 then
          Values_Page.Details:setText (Produce_Details (nil))
          Values_Page.Book_List:setChoices (Produce_Book_List (nil))
          
        else
          Values_Page.Details:setText (Produce_Details (Values_Page.Data_Matrix [Values_Page.Values_List.selected - 1]
                                                                                [Values_Page.Strength_List.selected - 4]
                                                                                [Values_Page.Own_List.selected]))
          Values_Page.Book_List:setChoices (Produce_Book_List (Values_Page.Data_Matrix [Values_Page.Values_List.selected - 1]
                                                                                       [Values_Page.Strength_List.selected - 4]
                                                                                       [Values_Page.Own_List.selected] [2]))
       end
        
      else
        Values_Page.Details:setText (Produce_Details (nil))
      end
      
      Values_Page.Book_Order_Label.visible = Values_Page.Book_List.active
      Values_Page.Book_List.visible = Values_Page.Own_List.active or
                                      Values_Page.Book_List.active      
      
    elseif keys [keybindings.right.key] and 
           Focus == "Values" then
      local active = 1
      
      for i, list in ipairs (Values_Page.Active_List) do
        if list.active then
          active = i + 1
          
          if active > #Values_Page.Active_List then
            active = 1
          end
          
          break
        end
      end
      
      for i, list in ipairs (Values_Page.Active_List) do
        list.active = (i == active)
      end
           
      if Values_Page.Own_List.active then
        if #Values_Page.Own_List.choices == 0 then
          Values_Page.Details:setText (Produce_Details (nil))
          Values_Page.Book_List:setChoices (Produce_Book_List (nil))
          
        else
          Values_Page.Details:setText (Produce_Details (Values_Page.Data_Matrix [Values_Page.Values_List.selected - 1]
                                                                                [Values_Page.Strength_List.selected - 4]
                                                                                [Values_Page.Own_List.selected]))
          Values_Page.Book_List:setChoices (Produce_Book_List (Values_Page.Data_Matrix [Values_Page.Values_List.selected - 1]
                                                                                       [Values_Page.Strength_List.selected - 4]
                                                                                       [Values_Page.Own_List.selected] [2]))
        end
      
      elseif Values_Page.Book_List.active then
        --  nothing
        
      elseif Values_Page.Remote_List.active then
        if #Values_Page.Remote_List.choices == 0 then
          Values_Page.Details:setText (Produce_Details (nil))
          
        else
          Values_Page.Details:setText (Produce_Details ({Values_Page.Remote_Data_Matrix
            [Values_Page.Values_List.selected - 1]
            [Values_Page.Strength_List.selected - 4]
            [Values_Page.Remote_List_Map [Values_Page.Remote_List.selected]].id}))
        end
        
      else
        Values_Page.Details:setText (Produce_Details (nil))
      end
      
      Values_Page.Book_Order_Label.visible = Values_Page.Book_List.active
      Values_Page.Book_List.visible = Values_Page.Own_List.active or
                                      Values_Page.Book_List.active      
      
    elseif keys [keybindings.left.key] and 
           Focus == "Authors" then
      local active = 1
      
      for i, list in ipairs (Authors_Page.Active_List) do
        if list.active then
          active = i - 1
          
          if active == 0 then
            active = #Authors_Page.Active_List
          end
          
          break
        end
      end
      
      for i, list in ipairs (Authors_Page.Active_List) do
        list.active = (i == active)
      end

      if Authors_Page.Works_List.active then
        --  nothing
      
      elseif Authors_Page.Book_List.active then
        Authors_Page.Details:setText (Produce_Details (Authors_Page.Authors [Authors_Page.Authors_List.selected]
                                                                            [2]
                                                                            [Authors_Page.Works_List.selected]))
        Authors_Page.Book_List:setChoices (Produce_Book_List (Authors_Page.Authors [Authors_Page.Authors_List.selected]
                                                                                   [2]
                                                                                   [Authors_Page.Works_List.selected] [2]), 1)
      
      else
        Authors_Page.Details:setText (Produce_Details (nil))
      end
      
      Authors_Page.Book_Order_Label.visible = Authors_Page.Book_List.active
      Authors_Page.Book_List.visible = Authors_Page.Works_List.active or
                                       Authors_Page.Book_List.active      
      
    elseif keys [keybindings.right.key] and 
           Focus == "Authors" then
      local active = 1
      
      for i, list in ipairs (Authors_Page.Active_List) do
        if list.active then
          active = i + 1
          
          if active > #Authors_Page.Active_List then
            active = 1
          end
          
          break
        end
      end
      
      for i, list in ipairs (Authors_Page.Active_List) do
        list.active = (i == active)
      end
      
      if Authors_Page.Works_List.active then
        Authors_Page.Details:setText (Produce_Details (Authors_Page.Authors [Authors_Page.Authors_List.selected]
                                                                            [2]
                                                                            [Authors_Page.Works_List.selected]))
        Authors_Page.Book_List:setChoices (Produce_Book_List (Authors_Page.Authors [Authors_Page.Authors_List.selected]
                                                                                   [2]
                                                                                   [Authors_Page.Works_List.selected] [2]), 1)
      
      elseif Authors_Page.Book_List.active then
        --  nothing
        
      else
        Authors_Page.Details:setText (Produce_Details (nil))
      end
      
      Authors_Page.Book_Order_Label.visible = Authors_Page.Book_List.active
      Authors_Page.Book_List.visible = Authors_Page.Works_List.active or
                                       Authors_Page.Book_List.active      
      
    elseif keys [keybindings.forbid_book.key] and
           Focus == "Main" and
           Main_Page.Book_List.active and
           #Main_Page.Book_List.choices > 0 then
      Main_Page.Filtered_Stock [Main_Page.List.selected].element [2] [Main_Page.Book_List.selected].flags.forbid =
        not Main_Page.Filtered_Stock [Main_Page.List.selected].element [2] [Main_Page.Book_List.selected].flags.forbid
        
      Main_Page.Book_List:setChoices (Produce_Book_List (Main_Page.Filtered_Stock [Main_Page.List.selected].element [2]), Main_Page.Book_List.selected)
      
    elseif keys [keybindings.dump_book.key] and
           Focus == "Main" and
           Main_Page.Book_List.active and
           #Main_Page.Book_List.choices > 0 then
      Main_Page.Filtered_Stock [Main_Page.List.selected].element [2] [Main_Page.Book_List.selected].flags.dump =
        not Main_Page.Filtered_Stock [Main_Page.List.selected].element [2] [Main_Page.Book_List.selected].flags.dump
        
      Main_Page.Book_List:setChoices (Produce_Book_List (Main_Page.Filtered_Stock [Main_Page.List.selected].element [2]), Main_Page.Book_List.selected)
      
    elseif keys [keybindings.trader_book.key] and
           Focus == "Main" and
           Main_Page.Book_List.active and
           #Main_Page.Book_List.choices > 0 then
      Main_Page.Filtered_Stock [Main_Page.List.selected].element [2] [Main_Page.Book_List.selected].flags.trader =
        not Main_Page.Filtered_Stock [Main_Page.List.selected].element [2] [Main_Page.Book_List.selected].flags.trader
        
      Main_Page.Book_List:setChoices (Produce_Book_List (Main_Page.Filtered_Stock [Main_Page.List.selected].element [2]), Main_Page.Book_List.selected)
      
    elseif keys [keybindings.zoom.key] and 
           Focus == "Main" and
           Main_Page.Book_List.active and
           #Main_Page.Book_List.choices > 0 then
      local item = Main_Page.Filtered_Stock [Main_Page.List.selected].element [2] [Main_Page.Book_List.selected]
      
      if item.pos.x ~= -30000 and
         item.pos.y ~= -30000 and
         item.pos.z ~= -30000 then
        local pos, key = Book_Location_And_Access_Key (item)

        persist_screen:sendInputToParent ({[df.interface_key [df.interface_key.OPTIONS]] = true,
                                           [df.interface_key [df.interface_key.LEAVESCREEN]] = true})  --  To exit any competing view mode.
        persist_screen:sendInputToParent (key)
        df.global.cursor.x = pos.x
        df.global.cursor.y = pos.y
        df.global.cursor.z = pos.z
        persist_screen:sendInputToParent ({[df.interface_key [df.interface_key.CURSOR_LEFT]] = true})  --  Jiggle to get DF to update.
        if item.pos.x ~= 0 then
          persist_screen:sendInputToParent ({[df.interface_key [df.interface_key.CURSOR_RIGHT]] = true})
        end
        
        Pre_Hiding_Focus = Focus
        Focus = "Hidden"      
        self.subviews.pages:setSelected (6)
        self.transparent = true
      end
      
    elseif keys [keybindings.forbid_book.key] and
           Focus == "Science" and
           Science_Page.Book_List.active and
           #Science_Page.Book_List.choices > 0 then
      Science_Page.Data_Matrix [Science_Page.Category_List.selected - 1]
                               [Science_Page.Topic_List.selected - 1]
                               [Science_Page.Own_List.selected] [2]
                               [Science_Page.Book_List.selected].flags.forbid =
        not Science_Page.Data_Matrix [Science_Page.Category_List.selected - 1]
                                     [Science_Page.Topic_List.selected - 1]
                                     [Science_Page.Own_List.selected] [2]
                                     [Science_Page.Book_List.selected].flags.forbid
                                       
      Science_Page.Book_List:setChoices (Produce_Book_List (Science_Page.Data_Matrix [Science_Page.Category_List.selected - 1]
                                                                                     [Science_Page.Topic_List.selected - 1]
                                                                                     [Science_Page.Own_List.selected] [2]), Science_Page.Book_List.selected)

    elseif keys [keybindings.dump_book.key] and
           Focus == "Science" and
           Science_Page.Book_List.active and
           #Science_Page.Book_List.choices > 0 then
      Science_Page.Data_Matrix [Science_Page.Category_List.selected - 1]
                               [Science_Page.Topic_List.selected - 1]
                               [Science_Page.Own_List.selected] [2]
                               [Science_Page.Book_List.selected].flags.dump =
        not Science_Page.Data_Matrix [Science_Page.Category_List.selected - 1]
                                     [Science_Page.Topic_List.selected - 1]
                                     [Science_Page.Own_List.selected] [2]
                                     [Science_Page.Book_List.selected].flags.dump
                                       
      Science_Page.Book_List:setChoices (Produce_Book_List (Science_Page.Data_Matrix [Science_Page.Category_List.selected - 1]
                                                                                     [Science_Page.Topic_List.selected - 1]
                                                                                     [Science_Page.Own_List.selected] [2]), Science_Page.Book_List.selected)
                                                                                     
    elseif keys [keybindings.trader_book.key] and
           Focus == "Science" and
           Science_Page.Book_List.active and
           #Science_Page.Book_List.choices > 0 then
      Science_Page.Data_Matrix [Science_Page.Category_List.selected - 1]
                               [Science_Page.Topic_List.selected - 1]
                               [Science_Page.Own_List.selected] [2]
                               [Science_Page.Book_List.selected].flags.trader =
        not Science_Page.Data_Matrix [Science_Page.Category_List.selected - 1]
                                     [Science_Page.Topic_List.selected - 1]
                                     [Science_Page.Own_List.selected] [2]
                                     [Science_Page.Book_List.selected].flags.trader
                                       
      Science_Page.Book_List:setChoices (Produce_Book_List (Science_Page.Data_Matrix [Science_Page.Category_List.selected - 1]
                                                                                     [Science_Page.Topic_List.selected - 1]
                                                                                     [Science_Page.Own_List.selected] [2]), Science_Page.Book_List.selected)
      
    elseif keys [keybindings.zoom.key] and 
           Focus == "Science" and
           Science_Page.Book_List.active and
           #Science_Page.Book_List.choices > 0 then
      local item = Science_Page.Data_Matrix [Science_Page.Category_List.selected - 1]
                                            [Science_Page.Topic_List.selected - 1]
                                            [Science_Page.Own_List.selected] [2]
                                            [Science_Page.Book_List.selected]
      
      if item.pos.x ~= -30000 and
         item.pos.y ~= -30000 and
         item.pos.z ~= -30000 then
         local pos, key = Book_Location_And_Access_Key (item)

         persist_screen:sendInputToParent ({[df.interface_key [df.interface_key.OPTIONS]] = true,
                                           [df.interface_key [df.interface_key.LEAVESCREEN]] = true})  --  To exit any competing view mode.
        persist_screen:sendInputToParent (key)
        df.global.cursor.x = pos.x
        df.global.cursor.y = pos.y
        df.global.cursor.z = pos.z
        persist_screen:sendInputToParent ({[df.interface_key [df.interface_key.CURSOR_LEFT]] = true})  --  Jiggle to get DF to update.
        if item.pos.x ~= 0 then
          persist_screen:sendInputToParent ({[df.interface_key [df.interface_key.CURSOR_RIGHT]] = true})
        end
        
        Pre_Hiding_Focus = Focus
        Focus = "Hidden"      
        self.subviews.pages:setSelected (5)
        self.transparent = true
      end
      
    elseif keys [keybindings.forbid_book.key] and
           Focus == "Values" and
           Values_Page.Book_List.active and
           #Values_Page.Book_List.choices > 0 then
      Values_Page.Data_Matrix [Values_Page.Values_List.selected - 1]
                               [Values_Page.Strength_List.selected - 4]
                               [Values_Page.Own_List.selected] [2]
                               [Values_Page.Book_List.selected].flags.forbid =
        not Values_Page.Data_Matrix [Values_Page.Values_List.selected - 1]
                                    [Values_Page.Strength_List.selected - 4]
                                    [Values_Page.Own_List.selected] [2]
                                    [Values_Page.Book_List.selected].flags.forbid
                                       
      Values_Page.Book_List:setChoices (Produce_Book_List (Values_Page.Data_Matrix [Values_Page.Values_List.selected - 1]
                                                                                   [Values_Page.Strength_List.selected - 4]
                                                                                   [Values_Page.Own_List.selected] [2]), Values_Page.Book_List.selected)
      
    elseif keys [keybindings.dump_book.key] and
           Focus == "Values" and
           Values_Page.Book_List.active and
           #Values_Page.Book_List.choices > 0 then
      Values_Page.Data_Matrix [Values_Page.Values_List.selected - 1]
                               [Values_Page.Strength_List.selected - 4]
                               [Values_Page.Own_List.selected] [2]
                               [Values_Page.Book_List.selected].flags.dump =
        not Values_Page.Data_Matrix [Values_Page.Values_List.selected - 1]
                                    [Values_Page.Strength_List.selected - 4]
                                    [Values_Page.Own_List.selected] [2]
                                    [Values_Page.Book_List.selected].flags.dump
                                       
      Values_Page.Book_List:setChoices (Produce_Book_List (Values_Page.Data_Matrix [Values_Page.Values_List.selected - 1]
                                                                                   [Values_Page.Strength_List.selected - 4]
                                                                                   [Values_Page.Own_List.selected] [2]), Values_Page.Book_List.selected)
      
    elseif keys [keybindings.trader_book.key] and
           Focus == "Values" and
           Values_Page.Book_List.active and
           #Values_Page.Book_List.choices > 0 then
      Values_Page.Data_Matrix [Values_Page.Values_List.selected - 1]
                               [Values_Page.Strength_List.selected - 4]
                               [Values_Page.Own_List.selected] [2]
                               [Values_Page.Book_List.selected].flags.trader =
        not Values_Page.Data_Matrix [Values_Page.Values_List.selected - 1]
                                    [Values_Page.Strength_List.selected - 4]
                                    [Values_Page.Own_List.selected] [2]
                                    [Values_Page.Book_List.selected].flags.trader
                                       
      Values_Page.Book_List:setChoices (Produce_Book_List (Values_Page.Data_Matrix [Values_Page.Values_List.selected - 1]
                                                                                   [Values_Page.Strength_List.selected - 4]
                                                                                   [Values_Page.Own_List.selected] [2]), Values_Page.Book_List.selected)
      
    elseif keys [keybindings.zoom.key] and 
           Focus == "Values" and
           Values_Page.Book_List.active and
           #Values_Page.Book_List.choices > 0 then
      local item = Values_Page.Data_Matrix [Values_Page.Values_List.selected - 1]
                                           [Values_Page.Strength_List.selected - 4]
                                           [Values_Page.Own_List.selected] [2]
                                           [Values_Page.Book_List.selected]
      
      if item.pos.x ~= -30000 and
         item.pos.y ~= -30000 and
         item.pos.z ~= -30000 then
         local pos, key = Book_Location_And_Access_Key (item)

         persist_screen:sendInputToParent ({[df.interface_key [df.interface_key.OPTIONS]] = true,
                                           [df.interface_key [df.interface_key.LEAVESCREEN]] = true})  --  To exit any competing view mode.
        persist_screen:sendInputToParent (key)
        df.global.cursor.x = pos.x
        df.global.cursor.y = pos.y
        df.global.cursor.z = pos.z
        persist_screen:sendInputToParent ({[df.interface_key [df.interface_key.CURSOR_LEFT]] = true})  --  Jiggle to get DF to update.
        if item.pos.x ~= 0 then
          persist_screen:sendInputToParent ({[df.interface_key [df.interface_key.CURSOR_RIGHT]] = true})
        end
        
        Pre_Hiding_Focus = Focus
        Focus = "Hidden"      
        self.subviews.pages:setSelected (5)
        self.transparent = true
      end
      
    elseif keys [keybindings.forbid_book.key] and
           Focus == "Authors" and
           Authors_Page.Book_List.active and
           #Authors_Page.Book_List.choices > 0 then
      Authors_Page.Authors [Authors_Page.Authors_List.selected]
                           [2]
                           [Authors_Page.Works_List.selected] [2]
                           [Authors_Page.Book_List.selected].flags.forbid =
        not  Authors_Page.Authors [Authors_Page.Authors_List.selected]
                                  [2]
                                  [Authors_Page.Works_List.selected] [2]
                                  [Authors_Page.Book_List.selected].flags.forbid
        
                                       
      Authors_Page.Book_List:setChoices (Produce_Book_List (Authors_Page.Authors [Authors_Page.Authors_List.selected]
                                                                                 [2]
                                                                                 [Authors_Page.Works_List.selected] [2]), Authors_Page.Book_List.selected)
      
    elseif keys [keybindings.dump_book.key] and
           Focus == "Authors" and
           Authors_Page.Book_List.active and
           #Authors_Page.Book_List.choices > 0 then
      Authors_Page.Authors [Authors_Page.Authors_List.selected]
                           [2]
                           [Authors_Page.Works_List.selected] [2]
                           [Authors_Page.Book_List.selected].flags.dump =
        not  Authors_Page.Authors [Authors_Page.Authors_List.selected]
                                  [2]
                                  [Authors_Page.Works_List.selected] [2]
                                  [Authors_Page.Book_List.selected].flags.dump
        
                                       
      Authors_Page.Book_List:setChoices (Produce_Book_List (Authors_Page.Authors [Authors_Page.Authors_List.selected]
                                                                                 [2]
                                                                                 [Authors_Page.Works_List.selected] [2]), Authors_Page.Book_List.selected)
      
    elseif keys [keybindings.trader_book.key] and
           Focus == "Authors" and
           Authors_Page.Book_List.active and
           #Authors_Page.Book_List.choices > 0 then
      Authors_Page.Authors [Authors_Page.Authors_List.selected]
                           [2]
                           [Authors_Page.Works_List.selected] [2]
                           [Authors_Page.Book_List.selected].flags.trader =
        not  Authors_Page.Authors [Authors_Page.Authors_List.selected]
                                  [2]
                                  [Authors_Page.Works_List.selected] [2]
                                  [Authors_Page.Book_List.selected].flags.trader
        
                                       
      Authors_Page.Book_List:setChoices (Produce_Book_List (Authors_Page.Authors [Authors_Page.Authors_List.selected]
                                                                                 [2]
                                                                                 [Authors_Page.Works_List.selected] [2]), Authors_Page.Book_List.selected)
           
    elseif keys [keybindings.zoom.key] and 
           Focus == "Authors" and
           Authors_Page.Book_List.active and
           #Authors_Page.Book_List.choices > 0 then
      local item = Authors_Page.Authors [Authors_Page.Authors_List.selected]
                                        [2]
                                        [Authors_Page.Works_List.selected] [2]
                                        [Authors_Page.Book_List.selected]
      
      if item.pos.x ~= -30000 and
         item.pos.y ~= -30000 and
         item.pos.z ~= -30000 then
         local pos, key = Book_Location_And_Access_Key (item)

         persist_screen:sendInputToParent ({[df.interface_key [df.interface_key.OPTIONS]] = true,
                                           [df.interface_key [df.interface_key.LEAVESCREEN]] = true})  --  To exit any competing view mode.
        persist_screen:sendInputToParent (key)
        df.global.cursor.x = pos.x
        df.global.cursor.y = pos.y
        df.global.cursor.z = pos.z
        persist_screen:sendInputToParent ({[df.interface_key [df.interface_key.CURSOR_LEFT]] = true})  --  Jiggle to get DF to update.
        if item.pos.x ~= 0 then
          persist_screen:sendInputToParent ({[df.interface_key [df.interface_key.CURSOR_RIGHT]] = true})
        end
        
        Pre_Hiding_Focus = Focus
        Focus = "Hidden"      
        self.subviews.pages:setSelected (5)
        self.transparent = true
      end
      
    elseif Focus == "Hidden" then
      if keys [df.interface_key [df.interface_key.SECONDSCROLL_DOWN]] then  --### Special case because of weird side effects when sending the whole list through.
        persist_screen:sendInputToParent ({[df.interface_key [df.interface_key.SECONDSCROLL_DOWN]] = true})
        
      elseif keys [df.interface_key [df.interface_key.SECONDSCROLL_UP]] then  --### Special case because of weird side effects when sending the whole list through.
        persist_screen:sendInputToParent ({[df.interface_key [df.interface_key.SECONDSCROLL_UP]] = true})
        
      else
        persist_screen:sendInputToParent (keys)
      end
    end

    self.super.onInput (self, keys)
  end

  --============================================================

  function Show_Viewer ()
    local screen = Ui {}
    persist_screen = screen
    screen:show ()
  end

  --============================================================

  Show_Viewer ()  
end

Librarian ()