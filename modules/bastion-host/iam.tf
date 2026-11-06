resource "aws_iam_instance_profile" "this" {
  count = var.enabled ? 1 : 0

  name_prefix = var.name_prefix
  role        = aws_iam_role.this[0].name

  tags = var.tags
}

resource "aws_iam_role" "this" {
  count = var.enabled ? 1 : 0

  name_prefix        = var.name_prefix
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.this.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  count = var.enabled ? 1 : 0

  role       = aws_iam_role.this[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "this" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    effect = "Allow"
  }
}
