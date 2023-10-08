resource "aws_subnet" "pub_subnet" {
  count = length(var.azs)

  vpc_id                  = var.vpc_id
  cidr_block              = cidrsubnet(var.vpc_cidr_block, 8, count.index)
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                     = "${var.cluster_name}-public-subnet-${var.azs[count.index]}"
    "karpenter.sh/discovery" = var.cluster_name
    terraform_module_name    = basename(abspath(path.module))

    # https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/deploy/subnet_discovery/
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = 1
    "karpenter.sh/discovery"                    = var.cluster_name
  }
}

resource "aws_subnet" "priv_subnet" {
  count = length(var.azs)

  vpc_id                  = var.vpc_id
  cidr_block              = cidrsubnet(var.vpc_cidr_block, 8, count.index + length(var.azs))
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name                  = "${var.cluster_name}-private-subnet-${var.azs[count.index]}"
    terraform_module_name = basename(abspath(path.module))

    # https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/deploy/subnet_discovery/
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = 1
    "karpenter.sh/discovery"                    = var.cluster_name
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = var.eip_id
  subnet_id     = aws_subnet.pub_subnet[0].id

  tags = {
    Name                  = "${var.cluster_name}-nat-gway-${var.azs[0]}"
    terraform_module_name = basename(abspath(path.module))
  }
}

resource "aws_route_table" "public" {
  vpc_id = var.vpc_id
  route {
    cidr_block = var.cidr_block_igw
    gateway_id = var.igway_id
  }
  tags = {
    Name                  = "${var.cluster_name}-public-routetable"
    terraform_module_name = basename(abspath(path.module))
  }
}

resource "aws_route_table" "private" {
  vpc_id = var.vpc_id
  route {
    cidr_block     = var.cidr_block_igw
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name                  = "${var.cluster_name}-private-routetable"
    terraform_module_name = basename(abspath(path.module))
  }
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.pub_subnet.*.id)

  subnet_id      = element(aws_subnet.pub_subnet.*.id, count.index)
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.priv_subnet.*.id)

  subnet_id      = element(aws_subnet.priv_subnet.*.id, count.index)
  route_table_id = aws_route_table.private.id
}
