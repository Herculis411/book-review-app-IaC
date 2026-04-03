########################################################################
# ALB Module — Public ALB (frontend) + Internal ALB (backend)
########################################################################

# ── Public ALB (Frontend) ──────────────────────────────────────────────────
resource "aws_lb" "public" {
  name               = "${var.project_name}-${var.environment}-pub-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.public_alb_sg_id]
  subnets            = var.web_subnet_ids

  enable_deletion_protection = false

  tags = { Name = "${var.project_name}-${var.environment}-public-alb" }
}

resource "aws_lb_target_group" "web" {
  name        = "${var.project_name}-${var.environment}-web-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200"
  }

  tags = { Name = "${var.project_name}-${var.environment}-web-tg" }
}

resource "aws_lb_listener" "web_http" {
  load_balancer_arn = aws_lb.public.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# ── Internal ALB (Backend) ─────────────────────────────────────────────────
resource "aws_lb" "internal" {
  name               = "${var.project_name}-${var.environment}-int-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [var.internal_alb_sg_id]
  subnets            = var.app_subnet_ids

  enable_deletion_protection = false

  tags = { Name = "${var.project_name}-${var.environment}-internal-alb" }
}

resource "aws_lb_target_group" "app" {
  name        = "${var.project_name}-${var.environment}-app-tg"
  port        = 3001
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/api/books"
    matcher             = "200"
  }

  tags = { Name = "${var.project_name}-${var.environment}-app-tg" }
}

resource "aws_lb_listener" "app_http" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 3001
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
