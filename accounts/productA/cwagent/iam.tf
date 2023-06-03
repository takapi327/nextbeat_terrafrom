data "aws_iam_policy" "ecs_task_execution_role_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      identifiers = ["ecs-tasks.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role" "cwagent_ecs_task_role" {
  name               = "CWAgentECSTaskRole"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  description        = "Allows ECS tasks to call AWS services on your behalf."
}

data "aws_iam_policy" "cloudwatch_agent_server_policy" {
  arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

data "aws_iam_policy_document" "cwagent_ecs_task" {
  source_policy_documents = [
    data.aws_iam_policy.cloudwatch_agent_server_policy.policy
  ]

  statement {
    effect    = "Allow"
    resources = ["*"]
    actions = [
      "ecs:DescribeTasks",
      "ecs:ListTasks",
      "ecs:DescribeContainerInstances",
      "ecs:DescribeServices",
      "ecs:ListServices"
    ]
  }

  statement {
    effect    = "Allow"
    resources = ["*"]
    actions = [
      "ec2:DescribeInstances",
      "ecs:DescribeTaskDefinition"
    ]
  }
}

resource "aws_iam_policy" "cwagent_ecs_task_role_policy" {
  name   = "ECSServiceDiscoveryInlinePolicy"
  policy = data.aws_iam_policy_document.cwagent_ecs_task.json
}

resource "aws_iam_role_policy_attachment" "cwagent_ecs_task_role_policy_attachment" {
  role       = aws_iam_role.cwagent_ecs_task_role.name
  policy_arn = aws_iam_policy.cwagent_ecs_task_role_policy.arn
}

resource "aws_iam_role" "cwagent_ecs_execution_role" {
  name               = "CWAgentECSExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  description        = "Allows ECS container agent makes calls to the Amazon ECS API on your behalf."
}


data "aws_iam_policy_document" "cwagent_ecs_execution" {
  source_policy_documents = [
    data.aws_iam_policy.ecs_task_execution_role_policy.policy,
    data.aws_iam_policy.cloudwatch_agent_server_policy.policy
  ]

  statement {
    effect    = "Allow"
    resources = ["*"]
    actions = [
      "ssm:GetParameters"
    ]
  }
}

resource "aws_iam_policy" "cwagent_ecs_execution_role_policy" {
  name   = "ECSSSMInlinePolicy"
  policy = data.aws_iam_policy_document.cwagent_ecs_execution.json
}

resource "aws_iam_role_policy_attachment" "cwagent_ecs_execution_role_policy_attachment" {
  role       = aws_iam_role.cwagent_ecs_execution_role.name
  policy_arn = aws_iam_policy.cwagent_ecs_execution_role_policy.arn
}
