# erbwiz
Generate Entity-Relationship Diagrams from text


## Preparing System

#### On MacOS

    $ brew install wget graphviz

#### On Ubuntu

    # sudo apt-get install graphviz

#### Both

    $ wget https://github.com/weapp/erbwiz/raw/master/erbwiz.rb
    $ chmod +x erbwiz.rb

## Generating images

    $ ./erbwiz.rb inputs.er output.pdf

#### Options:

The default notation is `ie`, but we can change to `uml`:

    $ ./erbwiz.rb -n uml inputs.er output.pdf


#### Example:

```
# Tables
[User] { color: :blue }
*id
blog_id* <nullable>
name

[Blog] { color: :orange }
*id
user_id*
title
logo <url>

[Post]
*id
blog_id*
title
body

# Relations
[User] 1--? [Blog]
[Blog] 1--* [Post]
[Post] +--* [Tag]
[Post] 1--* [Comment]
[User] 1--* [Comment]
[User] *--* [User] <friendship>

# Extras
[Post] == [Comment]
```
