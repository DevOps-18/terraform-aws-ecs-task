data "aws_region" "current" {
}

data "aws_caller_identity" "current" {
}

resource "aws_iam_role" "main" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
          "states.${data.aws_region.current.name}.amazonaws.com",
          "events.amazonaws.com"
        ]
      },
      "Effect": "Allow"
    }
  ]
}
EOF

}

resource "aws_iam_role_policy" "main" {
  role = aws_iam_role.main.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "events:PutTargets",
        "events:PutRule",
        "events:DescribeRule"
      ],
      "Resource": [
        "arn:aws:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:rule/StepFunctionsGetEventsForECSTaskRule"
      ],
      "Effect": "Allow"
    },
    {
      "Action": [
        "ecs:RunTask"
      ],
      "Resource": [
        "*"
      ],
      "Effect": "Allow"
    },
    {
      "Action": [
        "ecs:StopTask",
        "ecs:DescribeTasks"
      ],
      "Resource": "*",
      "Effect": "Allow"
    },
    {
      "Action": [
        "iam:PassRole"
      ],
      "Resource": [
        "*"
      ],
      "Effect": "Allow"
    }
  ]
}
EOF

}

resource "aws_iam_role_policy" "end_sns_topic" {
  count = var.end_sns_topic_arn == "" ? 0 : 1

  role = aws_iam_role.main.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sns:Publish"
      ],
      "Resource": [
        "${var.end_sns_topic_arn}"
      ]
    }
  ]
}
EOF

}

resource "aws_sfn_state_machine" "main" {
  name = var.name

  role_arn = aws_iam_role.main.arn

  definition = var.end_sns_topic_arn == "" ? file("${path.module}/src/v1.json") : templatefile("${path.module}/src/v2.json", { end_sns_topic_arn = var.end_sns_topic_arn })

  tags = var.tags
}

locals {
  access_statements_snippet = <<EOF
{
  "Effect": "Allow",
  "Action": [
    "states:StartExecution"
  ],
  "Resource": [
    "${aws_sfn_state_machine.main.id}"
  ]
},
{
  "Effect": "Allow",
  "Action": [
    "states:DescribeExecution"
  ],
  "Resource": [
    "arn:aws:states:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:execution:*:*"
  ]
}
EOF

}

locals {
  access_policy_snippet = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    ${local.access_statements_snippet}
  ]
}
EOF

}

