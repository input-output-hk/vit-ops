{ lib, config, ... }:
let
  bucketArn = "arn:aws:s3:::${config.cluster.s3Bucket}";

  pathPrefix = rootDir: dir:
    let
      fullPath = "${rootDir}/${dir}";
      splitPath = lib.splitString "/" fullPath;
      cascade = lib.foldl' (s: v:
        let p = "${s.path}${v}/";
        in {
          acc = s.acc ++ [ p ];
          path = p;
        }) {
          acc = [ "" ];
          path = "";
        } splitPath;
    in cascade.acc;

  allowS3For = prefix: rootDir: bucketDirs: {
    "${prefix}-s3-bucket-console" = {
      effect = "Allow";
      actions = [ "s3:ListAllMyBuckets" "s3:GetBucketLocation" ];
      resources = [ "arn:aws:s3:::*" ];
    };

    "${prefix}-s3-bucket-listing" = {
      effect = "Allow";
      actions = [ "s3:ListBucket" ];
      resources = [ bucketArn ];
      condition = lib.forEach bucketDirs (dir: {
        test = "StringLike";
        variable = "s3:prefix";
        values = pathPrefix rootDir dir;
      });
    };

    "${prefix}-s3-directory-actions" = {
      effect = "Allow";
      actions = [ "s3:*" ];
      resources = lib.unique (lib.flatten (lib.forEach bucketDirs (dir: [
        "${bucketArn}/${rootDir}/${dir}/*"
        "${bucketArn}/${rootDir}/${dir}"
      ])));
    };
  };
in {
  cluster.iam.roles.client.policies =
    allowS3For "artifacts" "infra" [ "artifacts" ];
}
