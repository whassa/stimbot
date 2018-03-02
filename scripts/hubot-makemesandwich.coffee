# Description:
#   Stimbotty like to make sandwich.
#
# Commands:
#   Stimbotty make me a sandwich - stimbotty respond with a sandwich


module.exports = (robot) ->
    
    robot.hear /make\s*me\s*.a\s*sandwich/, (res) ->
        res.send ":sandwich:"
