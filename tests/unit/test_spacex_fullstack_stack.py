import aws_cdk as core
import aws_cdk.assertions as assertions

from spacex_fullstack.spacex_fullstack_stack import SpacexFullstackStack

# example tests. To run these tests, uncomment this file along with the example
# resource in spacex_fullstack/spacex_fullstack_stack.py
def test_sqs_queue_created():
    app = core.App()
    stack = SpacexFullstackStack(app, "spacex-fullstack")
    template = assertions.Template.from_stack(stack)

#     template.has_resource_properties("AWS::SQS::Queue", {
#         "VisibilityTimeout": 300
#     })
